#!/usr/bin/env python
#coding: utf-8
from os.path import join, normpath, dirname
import time
import threading
import pickle
import logging
import zmq
import Queue
import tornado.ioloop
import tornado.web
from sockjs.tornado import SockJSConnection, SockJSRouter

PROJECT_ROOT = normpath(dirname(__file__))
STATIC_ROOT = join(PROJECT_ROOT, 'static')


class IndexHandler(tornado.web.RequestHandler):
    """Regular HTTP handler to serve the ping page"""
    def get(self):
        self.render('index.html')


class BroadcastConnection(SockJSConnection):
    clients = set()

    def on_open(self, info):
        self.clients.add(self)

    def on_message(self, msg):
        if message_queue.empty():
            self.broadcast(self.clients, None)
        else:
            new_debug_report = message_queue.get()
            self.broadcast(self.clients, new_debug_report)

    def on_close(self):
        self.clients.remove(self)


BroadcastRouter = SockJSRouter(BroadcastConnection, '/broadcast')

main_loop = None


def tornado_thread():

    logging.getLogger().setLevel(logging.DEBUG)

    app = tornado.web.Application(
        [(r"/", IndexHandler), ] +
        BroadcastRouter.urls +
        [(r'(.*)', tornado.web.StaticFileHandler, {'path': STATIC_ROOT})]
    )
    app.listen(8080)

    print('Listening on 0.0.0.0:8080')
    global main_loop
    main_loop = tornado.ioloop.IOLoop.instance()
    main_loop.start()


zeromq_socket = None
zeromq_context = None

ENABLE_ZEROMQ_LOOP = True

def zeromq_thread():
    global zeromq_context
    zeromq_context = zmq.Context()
    global zeromq_socket
    zeromq_socket = zeromq_context.socket(zmq.REP)
    zeromq_socket.bind('tcp://127.0.0.1:43000')
    while ENABLE_ZEROMQ_LOOP:
        try:
            data = pickle.loads(zeromq_socket.recv())
            message_queue.put(data)
            zeromq_socket.send('ok')
        except Exception as e:
            print(e)
            break

message_queue = None

if __name__ == '__main__':
    message_queue = Queue.Queue()
    threading.Thread(target=tornado_thread).start()
    threading.Thread(target=zeromq_thread).start()

    while True:
        try:
            time.sleep(1)
        except KeyboardInterrupt:
            main_loop.stop()
            ENABLE_ZEROMQ_LOOP = False
            zeromq_socket.close()
            zeromq_context.term()
            break