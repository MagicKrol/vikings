import tkinter as tk
import math

# =========================
# FUNKCJA CENY – PROSTA
# =========================

def price_after_sell(quantity, base_price, min_price, k):
    """
    quantity  - ile sprzedajesz
    base_price - cena początkowa
    min_price  - cena minimalna
    k          - szybkość spadku (im większe, tym szybciej cena leci w dół)
    """
    q = max(0.0, float(quantity))

    # bezpieczeństwo: min_price nie może być wyższa niż base_price
    if min_price > base_price:
        min_price = base_price

    # price(q) = min + (base-min) * e^(-k*q)
    return min_price + (base_price - min_price) * math.exp(-k * q)


# =========================
# GUI
# =========================

root = tk.Tk()
root.title("Prosty rynek – cena sprzedaży")

frame = tk.Frame(root, padx=10, pady=10)
frame.pack()

# --- suwaki ---

quantity_scale = tk.Scale(
    frame, from_=0, to=300, orient="horizontal",
    label="Sprzedana ilość (j)", length=400
)
quantity_scale.set(0)
quantity_scale.pack(fill="x")

base_price_scale = tk.Scale(
    frame, from_=0.5, to=10.0, resolution=0.1, orient="horizontal",
    label="Cena początkowa", length=400
)
base_price_scale.set(2.0)
base_price_scale.pack(fill="x")

min_price_scale = tk.Scale(
    frame, from_=0.0, to=5.0, resolution=0.1, orient="horizontal",
    label="Cena minimalna", length=400
)
min_price_scale.set(0.4)
min_price_scale.pack(fill="x")

k_scale = tk.Scale(
    frame, from_=0.001, to=0.05, resolution=0.001, orient="horizontal",
    label="Szybkość spadku (k)", length=400
)
# Dobre startowe: k ≈ 0.01 → 10 ~1.85, 100 ~1.0 przy base=2, min=0.4
k_scale.set(0.01)
k_scale.pack(fill="x")

# --- wyniki ---

price_label = tk.Label(
    frame,
    text="Cena jednostkowa: 0.00 zł",
    font=("Arial", 12, "bold"),
    pady=5
)
price_label.pack()

total_label = tk.Label(
    frame,
    text="Wartość transakcji: 0.00 zł",
    font=("Arial", 14, "bold"),
    pady=10
)
total_label.pack()


def update_price(*args):
    q = quantity_scale.get()
    base_price = base_price_scale.get()
    min_price = min_price_scale.get()
    k = k_scale.get()

    price = price_after_sell(q, base_price, min_price, k)
    total_value = price * q

    price_label.config(
        text=f"Cena jednostkowa: {price:.3f} zł"
    )
    total_label.config(
        text=f"Wartość transakcji: {total_value:.2f} zł"
    )


for s in (quantity_scale, base_price_scale, min_price_scale, k_scale):
    s.config(command=update_price)

update_price()
root.mainloop()
