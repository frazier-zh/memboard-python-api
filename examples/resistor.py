from memboard import Board
from memboard import unit
from memboard import Port

def func():
    pin1 = Port(socket='C11')
    pin2 = Port(socket='J11')

    board.time()
    board.measure(pin=pin2, drive_pin=pin1, v=0.2 *unit.V)

board = Board()
board.open()
board.run(func, every=1 *unit.ms, total=1 *unit.s, out='test')
board.close()