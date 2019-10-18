import sys
import os
if __name__ == '__main__':
    try:
        data = open(os.path.join(os.path.dirname(
            sys.argv[0]), '../routing_test.data'), 'rb').read()
    except FileNotFoundError:
        print('\033[31mCan\'t find file \'routing_test.data\'\033[0m')
    for i in range(0, len(data), 16):
        entry = data[i: i + 16]
        if entry[0:4] == b'\0\0\0\0':
            # insert
            print('%d.\t\033[32minsert %d.%d.%d.%d/%d -> %d.%d.%d.%d\033[0m' %
                  (i / 16 + 1, *list(entry[4: 8] + entry[11: 16])))
        elif entry[0:4] == b'\0\0\0\1':
            # query
            print('%d.\t\033[33mquery  %d.%d.%d.%d\033[0m' %
                  (i / 16 + 1, *list(entry[4: 8])))
            if entry[11] == 0:
                print('\t\033[34mexpect None\033[0m')
            else:
                print('\t\033[34mexpect %d.%d.%d.%d\033[0m' %
                      tuple(entry[12: 16]))
        elif entry[0:4] == b'\xff\xff\xff\xff':
            # terminate
            print('\033[31mEOF\033[0m')
        else:
            print('\033[31mInvalid data\033[0m')
            exit(0)
