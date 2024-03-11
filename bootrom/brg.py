#!python3
#
# Brute-force bitrate searcher for OX16C954
#
xtal = 33000000
max_error = 0.05

sc_range = range(16, 17)
prescaler_range = range(8, 256)
#prescaler_range = range(32, 33)

class Target:
    def __init__(self, rate):
        self.rate = rate
        self.max_error = rate * max_error
        self.best_error = rate
        self.best_rate = 0
        self.sc = 0
        self.divisor = 0
        self.prescaler = 0

    def consider(self, sc, divisor, prescaler):
        actual_rate = xtal / (sc * divisor * (prescaler / 8))
        error = abs(self.rate - actual_rate)
        if (error < self.max_error) and (error < self.best_error):
            self.best_error = error
            self.best_rate = actual_rate
            self.sc = sc
            self.divisor = divisor
            self.prescaler = prescaler

    def __str__(self):
        if self.best_error == self.rate:
            return f"{self.rate}: not available"
        return (f"{self.rate}: "
                f"sc {self.sc}  divisor {self.divisor >> 8},{self.divisor % 256}  prescaler {self.prescaler} "
                f"=> {int(self.best_rate)}  error {int(self.best_error)} / {self.best_error / self.rate * 100:.2f})%")


targets = [Target(115200), Target(230400), Target(921600)]

for sc in sc_range:
    print(f"sc = {sc}...")
    for prescaler in prescaler_range:
        for divisor in range(1, 65536):
            for target in targets:
                target.consider(sc, divisor, prescaler)

for target in targets:
    print(target)
