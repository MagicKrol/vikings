import random
import json
import time

# przykładowe przedrostki
prefixes = [
    # Anglo-saskie
    "North", "South", "East", "West",
    "Ash", "Oak", "Stone", "Wood", "Green", "River", "King", "Saint", "Whit", "Black", "Red",
    # Nordyckie
    "Reyk", "Akr", "Hafn", "Berg", "Sand", "Vatn", "Tor", "Os", "Kirk", "Hvit", "Ey", "Hella", "Foss"
]

# przykładowe końcówki
suffixes = [
    # Anglo-saskie
    "ham", "ton", "ford", "wich", "ley", "worth", "bury", "mere", "don", "chester",
    # Nordyckie
    "by", "thorpe", "holme", "fell", "thwaite", "vik", "stadir", "fjord", "dal", "nes",
    "oy", "havn", "berg", "fjell", "haug"
]

def generate_names(n):
    names = set()
    while len(names) < n:
        name = random.choice(prefixes) + random.choice(suffixes)
        names.add(name)
    return list(names)

if __name__ == "__main__":
    liczba = 500  # <<< tutaj wpisz ile nazw chcesz
    result = generate_names(liczba)

    timestamp = int(time.time())
    filename = f"regions-{timestamp}.json"

    with open(filename, "w", encoding="utf-8") as f:
        json.dump(result, f, indent=2, ensure_ascii=False)

    print(f"✔ Zapisano {len(result)} nazw do pliku {filename}")
