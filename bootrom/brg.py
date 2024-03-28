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
OVERSAMPLE = 16
PRE_FRAC = 8


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
        return (f"{self.rate:10d}: "
                f"sc {self.sc}  divisor {self.divisor >> 8},{self.divisor % 256}  prescaler {self.prescaler} "
                f"=> {self.best_rate}  error {self.best_error} / {self.best_error / self.rate * 100:.2f}%")


def integer_sqrt(n):
    x = n // 2
    while True:
        prev_x = x
        x = (x + n // x) // 2
        if abs(x - prev_x) <= 1:
            return (x - 1) if (x * x) > n else x


def guess(target):
    n = (CLOCK * PRE_FRAC) // (target.rate * OVERSAMPLE)
    lf = integer_sqrt(n)
    while lf > 0:
        hf = n // lf
        if (lf >= 8) and (lf < 256):
            target.consider(OVERSAMPLE, hf, lf)
            target.consider(OVERSAMPLE, hf + 1, lf)
        elif (hf >= 8) and (hf < 256):
            target.consider(OVERSAMPLE, lf, hf)
            target.consider(OVERSAMPLE, lf, hf + 1)
        lf -= 1


for target in [Target(9600), Target(115200), Target(2062500)]:
    guess(target)
    print(target)
