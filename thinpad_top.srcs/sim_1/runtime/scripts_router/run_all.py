"""
执行目录下所有脚本
"""

import sys
import os

if __name__ == '__main__':
    # locate this script
    directory = os.path.dirname(os.path.abspath(__file__))
    for filename in os.listdir(directory):
        path = os.path.join(directory, filename)
        if os.path.samefile(path, sys.argv[0]):
            continue
        if filename[-3:] == '.py':
            command = 'python3 ' + path
            print(command)
            os.system(command)
