#coding: utf-8
import zmq
import pickle


context = zmq.Context()
socket = context.socket(zmq.REQ)
socket.connect('tcp://127.0.0.1:43000')

data = 'url', u'<p>hi999999!</p>'
socket.send(pickle.dumps(data))
