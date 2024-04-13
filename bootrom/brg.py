#!python3
#
# Bitrate calculator for OX16C954
#
#                        CLOCK
# bitrate =  ----------------------------------
#            oversampling * divisor * prescaler
#
# oversampling is 4-16
# divisor is 1-65535
# prescaler is 5.3 fixed point, range 1 - 31.875
#

# For IP940
CLOCK = 33333333
PRE_FRAC = 8

rate_list = [
    921600,
    460800,
    230400,
    115200,
    153600,
    78600,
    57600,
    38400,
    19200,
    9600,
    4800,
    3600,
    2400,
    2000,
    1800,
    1200,
    600,
    300,
]

oversample_list = [
    16
]


class Target:
    def __init__(self, rate):
        self.rate = rate
        self.best_error = rate

    def consider(self, sc, divisor, prescaler):
        actual_rate = (CLOCK * PRE_FRAC) // (sc * divisor * prescaler)
        error = abs(self.rate - actual_rate)
        if error < self.best_error:
            self.best_error = error
            self.best_rate = actual_rate
            self.sc = sc
            self.divisor = divisor
            self.prescaler = prescaler

    def __str__(self):
        if self.best_error == self.rate:
            return f"{self.rate}: not available"
#        return (f"{self.rate:10d}: "
#                f"TCR {self.sc % 16:#04x}  DLx {self.divisor >> 8:#04x},{self.divisor % 256:#04x} CPR {self.prescaler:#04x} "
#                f"=> {self.best_rate}  error {self.best_error} / {self.best_error / self.rate * 100:.2f}%")
        return (f"B{self.rate}, {self.prescaler:#04x}, {self.divisor >> 8:#04x}, {self.divisor & 0xff:#04x}, {self.sc & 0xf:#04x}")


def integer_sqrt(n):
    x = n // 2
    while True:
        prev_x = x
        x = (x + n // x) // 2
        if abs(x - prev_x) <= 1:
            return (x - 1) if (x * x) > n else x


def guess(target):
    for oversample in oversample_list:
        n = (CLOCK * PRE_FRAC) // (target.rate * oversample)
        lf = integer_sqrt(n)
        while lf > 0:
            hf = n // lf
            if (lf >= 8) and (lf < 256):
                target.consider(oversample, hf, lf)
                target.consider(oversample, hf + 1, lf)
            elif (hf >= 8) and (hf < 256):
                target.consider(oversample, lf, hf)
                target.consider(oversample, lf, hf + 1)
            lf -= 1


for rate in rate_list:
    target = Target(rate)
    guess(target)
    print(target)
