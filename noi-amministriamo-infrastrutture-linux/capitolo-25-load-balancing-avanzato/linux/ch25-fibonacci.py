#!/usr/bin/env python3
# Esempio didattico: calcolo ricorsivo CPU-bound tramite Nginx + fcgiwrap.
# Installare con chmod 755 sotto /usr/lib/cgi-bin/.
# Su backend B cambiare la stringa Backend A in Backend B - dhcp-client01.
from time import perf_counter

def fibonacci(n):
    if n < 2:
        return n
    return fibonacci(n - 1) + fibonacci(n - 2)

start = perf_counter()
result = fibonacci(40)
elapsed = perf_counter() - start

print("Content-Type: text/plain; charset=utf-8")
print()
print("Backend A - linux-client01")
print(f"Fibonacci(40) = {result}")
print(f"Calcolo: {elapsed:.3f} secondi")
