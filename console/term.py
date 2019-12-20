#!/usr/bin/env python
# -*- coding: UTF-8 -*-

import argparse
import re
import select
import serial
import socket
import sys

from PyQt5.QtWidgets import QApplication, QWidget, QTextEdit, QVBoxLayout, QPushButton, QStatusBar, QMainWindow
from PyQt5.QtCore import QCoreApplication, Qt, QThread, pyqtSignal
from PyQt5.QtGui import QTextCursor

inp = None
outp = None

class tcp_wrapper:
    def __init__(self, sock=None):
        if sock is None:
            self.sock = socket.socket(
                socket.AF_INET, socket.SOCK_STREAM)
        else:
            self.sock = sock

    def connect(self, host, port):
        self.sock.connect((host, port))

    def write(self, msg):
        totalsent = 0
        MSGLEN = len(msg)
        while totalsent < MSGLEN:
            sent = self.sock.send(msg[totalsent:])
            if sent == 0:
                raise RuntimeError("socket connection broken")
            totalsent = totalsent + sent

    def flush(self): # dummy
        pass

    def read(self, MSGLEN):
        chunks = []
        bytes_recd = 0
        while bytes_recd < MSGLEN:
            chunk = self.sock.recv(min(MSGLEN - bytes_recd, 2048))
            # print 'read:...', list(map(lambda c: hex(ord(c)), chunk))
            if chunk == b'':
                raise RuntimeError("socket connection broken")
            chunks.append(chunk)
            bytes_recd = bytes_recd + len(chunk)
        return b''.join(chunks)

    def reset_input_buffer(self):
        local_input = [self.sock]
        while True:
            inputReady, o, e = select.select(local_input, [], [], 0.0)
            if len(inputReady) == 0:
                break
            for s in inputReady:
                s.recv(1)

def InitializeSerial(pipe_path, baudrate):
    global outp, inp
    sys.stdout.write("connecting to serial %s@%s..." % (pipe_path, baudrate))
    sys.stdout.flush()
    tty = serial.Serial(port=pipe_path, baudrate=baudrate)
    tty.reset_input_buffer()
    inp = tty
    outp = tty
    print('connected')
    return True

def InitializeTCP(host_port):
    ValidIpAddressRegex = re.compile("^((([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])):(\d+)$");
    ValidHostnameRegex = re.compile("^((([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])):(\d+)$");

    if ValidIpAddressRegex.search(host_port) is None and \
        ValidHostnameRegex.search(host_port) is None:
        return False

    match = ValidIpAddressRegex.search(host_port) or ValidHostnameRegex.search(host_port)
    groups = match.groups()
    ser = tcp_wrapper()
    host, port = groups[0], groups[4]
    sys.stdout.write("connecting to %s:%s..." % (host, port))
    sys.stdout.flush()
    ser.connect(host, int(port))
    print("connected")

    global outp, inp
    outp = ser
    inp = ser
    return True

def InitializeDebug():
    global outp, inp
    outp = sys.stdout
    inp = sys.stdin
    
class ReceiverThread(QThread):
    signal = pyqtSignal(list)

    def __init__(self, inp, parent=None):
        super(ReceiverThread, self).__init__(parent)
        self.inp = inp

    def run(self):
        while True:
            val = inp.read(1)
            if val == b'\x7f':
                self.signal.emit([0, 2])
            try:
                self.signal.emit([val.decode('utf-8'), 1])
            except: # 有时编码会有问题
                self.signal.emit([0, 0])

class MainWindow(QMainWindow):
    def __init__(self, writer, receiver):
        super(MainWindow, self).__init__()
        self._init_ui()

    def _init_ui(self):
        self.resize(720, 405)
        self.setWindowTitle('root@thinrouter.4')

        self.textEdit = QTextEdit()
        self.textEdit.setReadOnly(True)
        self.setCentralWidget(self.textEdit)

        self.statusBar = QStatusBar()
        self.setStatusBar(self.statusBar)

        global inp
        self.receiver = ReceiverThread(inp)
        self.receiver.signal.connect(self.receive)
        self.receiver.start()

        self.show()

    def receive(self, data):
        if data[1] == 2:
            self.textEdit.textCursor().deletePreviousChar()
            self.textEdit.textCursor().movePosition(QTextCursor.PreviousCharacter, QTextCursor.KeepAnchor)
        elif data[1] == 0:
            self.statusBar.showMessage('Decode error')
        else:
            if data[0] == '\0':
                self.textEdit.clear()
            else:
                self.textEdit.insertPlainText(data[0])
        self.textEdit.moveCursor(QTextCursor.End)

    def keyFilter(self, event):
        key = event.key()
        if key == Qt.Key_Backspace:
            return 'Backspace'
        if key == Qt.Key_Return: # Windows 上可能是 Key_Enter
            return 'Enter'
        if 32 <= key and key <= 126: # ASCII 可见字符
            return event.text()
        return None

    def send(self, byte):
        if byte == 'Enter':
            outp.write(b'\x01')
        elif byte == 'Backspace':
            outp.write(b'\x7f')
        else:
            outp.write(bytearray(byte, 'utf-8'))

    def keyReleaseEvent(self, event):
        converted = self.keyFilter(event)
        if converted != None:
            self.statusBar.showMessage('Signal sent: ' + converted)
            self.send(converted)
        else:
            self.statusBar.showMessage('Key ignored: ' + str(event.key()))

def PyQtMain():
    app = QApplication(sys.argv)
    window = MainWindow(outp, inp)
    sys.exit(app.exec_())

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Term for console@thinrouter.4')
    parser.add_argument('-t', '--tcp', default=None, help='TCP server address:port for communication')
    parser.add_argument('-s', '--serial', default=None, help='Serial port name (e.g. /dev/ttyACM0, COM3)')
    parser.add_argument('-b', '--baud', default=9600, help='Serial port baudrate (9600 by default)')
    parser.add_argument('-d', '--debug', action='store_true', help='Debug mode')
    args = parser.parse_args()

    if args.debug:
        InitializeDebug()
    elif args.tcp:
        if not InitializeTCP(args.tcp):
            print('Failed to establish TCP connection')
            exit(1)
    elif args.serial:
        if not InitializeSerial(args.serial, args.baud):
            print('Failed to open serial port')
            exit(1)
    else:
        parser.print_help()
        exit(1)

    PyQtMain()