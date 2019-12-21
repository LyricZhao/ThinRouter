try:
    import readline
except:
    pass
try: type(raw_input)
except NameError: raw_input = input

outp = open('console_test.bin', 'wb')

def MainLoop():
    while True:
        cmd = raw_input('>> ')
        if cmd == 'end':
            break
        outp.write(bytearray(cmd, 'utf-8'))
        outp.write(b'\x01')

if __name__ == '__main__':
    print('Enter the simulated command below, type end to exit')
    MainLoop()
    outp.close()