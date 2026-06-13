import random


def millerRabin(n: int, rounds: int = 40) -> bool:
    """
    Miller-Rabin probabilistic primality test.
    """

    if n < 2:
        return False
    if n == 2 or n == 3:
        return True
    if n % 2 == 0:
        return False

    r, d = 0, n - 1
    while d % 2 == 0:
        r += 1
        d //= 2

    for _ in range(rounds):
        a = random.randrange(2, n - 1)
        x = pow(a, d, n)

        if x == 1 or x == n - 1:
            continue

        for _ in range(r - 1):
            x = pow(x, 2, n)
            if x == n - 1:
                break
        else:
            return False

    return True


def genPrime(bits: int = 1024) -> int:
    while True:
        candidate = random.getrandbits(bits)
        candidate |= (1 << (bits - 1))
        candidate |= (1 << (bits - 2))
        candidate |= 1

        if millerRabin(candidate):
            return candidate

