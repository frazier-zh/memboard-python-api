import memboard as mb
from memboard import board
import memboard.unit as u

def run(output):
    mb.reset_all()
    
    top_pin = mb.socket('C11')
    bottom_pin = mb.socket('J11')

    output['time'] = mb.time()
    output['current'] = mb.measure(pin=bottom_pin, drive_pin=top_pin, v=2 *u.V)

board.open()
mb.execute(run, every=1 *u.ms, total=10 *u.s, out='test')
board.close()