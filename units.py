#!/usr/bin/env python3
from math import floor
import argparse
import json
from typing import Tuple, Optional

def allocate_with_unit0(
    budget: int,
    total_units: int,
    costs: Tuple[int, ...] = (1, 3, 2),     # koszty jednostek 1..k
    props: Tuple[int, ...] = (3, 2, 1),     # proporcje jednostek 1..k (całkowite)
    unit0_share: float = 0.40,              # udział jednostki 0 (dokładnie floor(share * total_units))
    resource_limit: Optional[int] = None,   # limit zasobu dla jednostki z resource_unit_index (None = brak limitu)
    resource_unit_index: int = 1            # 0-based index: 1 oznacza J2
):
    """
    Zwraca słownik z ilościami: unit_0, unit_1..unit_k oraz statystyki.
    Zasady:
      - unit_0: floor(unit0_share * total_units), koszt 0.
      - Jednostki 1..k mieszczą się w budżecie i w limicie sztuk (≤ total_units - unit_0),
        trzymając proporcje przez pełne pakiety + dokładanie reszty.
      - Jednostka z indeksu `resource_unit_index` zużywa 1 zasób/szt., łączny limit `resource_limit`.
    """
    assert len(costs) == len(props) and all(p > 0 for p in props), "Koszty i proporcje muszą być dodatnie i mieć tę samą długość."
    assert 0 <= resource_unit_index < len(props), "resource_unit_index poza zakresem."

    # 1) Jednostka 0 (darmowa)
    unit0 = floor(unit0_share * total_units)
    paid_units_cap = max(0, total_units - unit0)

    # 2) Pakiet proporcji
    P = sum(props)                                      # sztuk w pakiecie
    S = sum(c * p for c, p in zip(costs, props))        # koszt pakietu

    # 3) Ile pełnych pakietów? (budżet, sztuki, zasób)
    limits = [budget // S if S > 0 else 0, paid_units_cap // P if P > 0 else 0]
    if resource_limit is not None:
        # każdy pakiet zużywa props[resource_unit_index] zasobów tej jednostki
        r_per_pack = props[resource_unit_index]
        limits.append(resource_limit // r_per_pack if r_per_pack > 0 else 0)
    full_packages = min(limits) if limits else 0

    x_paid = [full_packages * p for p in props]
    budget_left = budget - full_packages * S
    units_left = paid_units_cap - full_packages * P
    resource_used = x_paid[resource_unit_index]
    resource_left = None if resource_limit is None else max(0, resource_limit - resource_used)

    # 4) Sekwencja „częściowego pakietu”
    seq = []
    for i, p in enumerate(props):
        seq += [i] * p  # np. (3,2,1) -> [0,0,0,1,1,2]

    # 5) Dokładanie pojedynczych sztuk
    cheapest = min(costs) if costs else 0
    changed = True
    while changed and units_left > 0 and budget_left >= cheapest:
        changed = False
        for i in seq:
            # zasób dla jednostki resource_unit_index
            if resource_limit is not None and i == resource_unit_index and resource_used >= resource_limit:
                continue
            if units_left > 0 and budget_left >= costs[i]:
                x_paid[i] += 1
                units_left  -= 1
                budget_left -= costs[i]
                if i == resource_unit_index and resource_limit is not None:
                    resource_used += 1
                changed = True
            if units_left == 0 or budget_left < cheapest:
                break

    # 6) Wynik
    result = {f"unit_{i+1}": x_paid[i] for i in range(len(x_paid))}
    result["unit_0"] = unit0
    result["total_cost"] = sum(c * q for c, q in zip(costs, x_paid))
    result["paid_units_used"] = sum(x_paid)
    result["total_units_used"] = result["paid_units_used"] + unit0
    result["units_unused"] = total_units - result["total_units_used"]
    result["budget_left"] = budget - result["total_cost"]
    result["resource_used_J{}".format(resource_unit_index+1)] = resource_used
    if resource_limit is not None:
        result["resource_left"] = max(0, resource_limit - resource_used)
        result["resource_limit"] = resource_limit
    return result


def parse_list_of_ints(text: str) -> Tuple[int, ...]:
    return tuple(int(x.strip()) for x in text.split(",") if x.strip())

def main():
    ap = argparse.ArgumentParser(description="Alokacja z jednostką 0 (40%), proporcjami i limitem zasobu dla J2.")
    ap.add_argument("koszt", type=int, help="Budżet całkowity (int).")
    ap.add_argument("dostepne_jednostki", type=int, help="Całkowita dostępna liczba sztuk (int).")
    ap.add_argument("--costs", default="1,3,2", help="Koszty jednostek 1..k, np. '1,3,2'.")
    ap.add_argument("--props", default="3,2,1", help="Proporcje jednostek 1..k, np. '3,2,1'. (całkowite)")
    ap.add_argument("--unit0-share", type=float, default=0.40, help="Udział jednostki 0 (0..1). Domyślnie 0.40.")
    ap.add_argument("--resource", type=int, default=None, help="Limit zasobu dla jednostki nr 2 (J2).")
    ap.add_argument("--resource-index", type=int, default=2,
                    help="Która jednostka zużywa zasób (1-based). Domyślnie 2 (czyli J2).")

    args = ap.parse_args()
    costs = parse_list_of_ints(args.costs)
    props = parse_list_of_ints(args.props)
    resource_index_0b = max(1, args.resource_index) - 1  # konwersja na 0-based, min. 1-based=1

    out = allocate_with_unit0(
        budget=args.koszt,
        total_units=args.dostepne_jednostki,
        costs=costs,
        props=props,
        unit0_share=args.unit0_share,
        resource_limit=args.resource,
        resource_unit_index=resource_index_0b
    )
    print(json.dumps(out, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
