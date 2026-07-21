# Horn of the Warlord: Player Guide

This guide explains the player-facing mechanics of the game: what each system does, why it matters, and how to use it during a campaign, scenario, or custom skirmish.

## Regions and terrain

### Region types and what they are good for

Each region type has a strategic role. A good region is not only a source of income; it can also be a road, a shield, a recruitment base, or the place where an enemy army loses its advantage.

**Grassland** - Grassland is the foundation of a stable realm. It is the main source of food on generated maps, and food is what lets armies and garrisons stay in the field without starving. Grassland also tends to be the easiest land to move through, so a chain of grassland regions can become a fast reinforcement route between castles and front lines.

**Forest** - Forest regions are your practical wood supply. Wood matters for early castle construction and siege equipment, so forests often decide whether a player can expand defenses or prepare a serious assault. Forests also slow military tempo, making them useful as buffers around valuable regions.

**Hills** - Hills are the stone and ore terrain. They are slower to cross than grassland, but they can become extremely valuable once protected, because they support castle-building resources and can reveal iron or gold through ore search. A good hills region can become the resource base for stronger castles and better-equipped armies.

**Forest Hills** - Forest Hills combine the advantages and problems of both forests and hills. They can contribute wood, stone, and ore potential, but they are slow to move through and usually take time to exploit. Treat them as strong strategic anchors rather than easy expansion land.

**Mountains** - Mountains are not economic targets. They are barriers. Their value is positional: they shape borders, block routes, create chokepoints, and can protect a flank simply by being impossible to march through.

### How map mode changes region data

In custom/skirmish maps, region resources and population are generated from terrain rules. This means one map may give you a food-rich start, while another may force you to fight early for forests, hills, or ore-capable land. Generated region data affects not only income, but also population, recruit potential, starting garrison strength, and the overall pressure of the opening turns.

In missions, region data is fixed by the mission setup. That makes mission maps more like prepared strategic situations: key regions already have intended roles, and success often comes from reading those roles correctly.

On generated maps, some resource amounts are more likely than others.

**Grassland food**

1. Resource amount 1: 45%
2. Resource amount 2: 35%
3. Resource amount 3: 20%

**Forest wood**

1. Resource amount 1: 55%
2. Resource amount 2: 30%
3. Resource amount 3: 15%

**Hills stone**

1. Resource amount 1: 45%
2. Resource amount 2: 35%
3. Resource amount 3: 20%

**Forest Hills wood**

1. Resource amount 1: 70%
2. Resource amount 2: 30%

**Forest Hills stone**

1. Resource amount 0: 45%
2. Resource amount 1: 35%
3. Resource amount 2: 20%

### Movement and control tempo

Movement cost controls operational tempo. It decides whether an army can reinforce a castle this turn, reach a weak enemy region, or escape before a counterattack.

1. **Grassland**: 2 movement points
2. **Hills**: 3 movement points
3. **Forest**: 3 movement points
4. **Forest Hills**: 4 movement points
5. **Mountains**: impassable

Low-cost routes let you react faster and punish overextension. High-cost routes slow both attack and rescue, which makes them useful buffers if you already control the entrances.

### Ore discovery and mining access

Hills and Forest Hills can contain hidden ore potential, but iron and gold are not automatically available. A region must be searched before that ore becomes part of your economy.

Each ore search costs 10 Gold. A region can be searched once per turn, up to 3 total attempts. Each attempt has a 25% chance to discover ore. If discovery succeeds, the result is usually Iron (80%) and sometimes Gold (20%). Once ore is discovered, searching in that region ends.

This makes ore a deliberate investment. Searching too early can drain gold you need for armies or castles, but ignoring ore-capable regions can leave you short of iron when higher-tier troops become available.

## Economy and growth

### The economy loop each turn

Your economy is not only what your regions produce. At the start of your turn, owned regions generate resources, then armies and garrisons consume food. If there is not enough food, famine kills soldiers across your forces.

Food is therefore both an economic resource and a military resource. A realm with strong gold income but weak food can still lose campaigns because it cannot keep soldiers alive between battles.

### Taxes and Gold income

Every owned region generates taxes from its population. A region always provides 1 base Gold, then adds another 1 Gold for every full population band it contains. Higher region levels make those bands smaller, so the same population pays more tax after promotion.

1. **Shire (L1)**: +1 Gold per 150 population
2. **County (L2)**: +1 Gold per 135 population
3. **March (L3)**: +1 Gold per 120 population
4. **Duchy (L4)**: +1 Gold per 105 population
5. **Province (L5)**: +1 Gold per 90 population

For example, a region with 450 population generates 4 Gold as a Shire: 1 base Gold plus 3 population increments. The same 450 population generates 6 Gold as a Province: 1 base Gold plus 5 population increments.

Taxes are separate from Gold deposits. A discovered Gold resource adds its normal regional resource production on top of population taxes, and region-level resource bonuses apply to that deposit output rather than to the tax calculation.

### How region growth actually works

Population growth depends on several pressures at once: base growth, recruit availability, local food, and level-based promotion bonus. The most important idea is that recruitment and growth are linked. Heavy recruitment pulls people out of the region pool, and a drained recruit pool slows the region's future population growth.

For example, if a region could receive up to 2% base growth but its recruit pool is only about 20% full, the base growth contribution is only about 0.4% before other bonuses. Local food can help recover that momentum, while constant over-recruitment keeps a region from developing quickly.

Local food adds +0.1% growth per food point in the region. This is why food regions are more than supply depots: they become healthier population centers and better long-term manpower bases.

### Promotion effects on growth and replenish

Promotion has two ongoing effects and one short replenish boost.

1. **Growth bonus (permanent, level-based)**: each level above L1 adds +0.5% to growth.

2. **Resource output bonus (permanent, level-based)**: each level above L1 increases local resource output by 37.5%.

3. **Recruits replenish pool bonus (temporary, 2 turns)**: after promotion, the base recruit replenish rate is doubled for 2 turns.

### Demotion and recovery

Promotion is not permanent. A region above L1 can be demoted by one level when you need to reduce its upkeep burden or recover from overexpansion.

1. Demotion takes 1 turn and completes at the start of your next turn.
2. Demoting a region returns 5 Food.
3. A region cannot be promoted and demoted in the same turn.
4. L1 regions cannot be demoted.

Demotion lowers the region's recruit capacity, growth bonus, and resource output, so it is best used to stabilize an economy rather than as a routine source of Food.

### Region levels and what they represent

Region level defines how much of the population can be available as recruits and how productive the region becomes. Each level above the first increases local resource output by 37.5%, so promotion improves both economy and manpower.

**Shire (L1)** - A Shire is a small frontier region. It can support only a modest recruit pool, with a cap equal to 4% of population. Shires are useful for early expansion and border presence, but they should not be expected to carry a long war alone.

**County (L2)** - A County is the first step toward stability. Its recruit cap rises to 5% of population, and its resources are stronger than a Shire's. Counties are good early economic bases and make safer anchors for newly claimed land.

**March (L3)** - A March is a serious border region. With a 6% recruit cap and better resource output, it can support active military operations more reliably. A March near a castle can become the heart of a local recruitment network.

**Duchy (L4)** - A Duchy is a high-value regional center. Its 7% recruit cap and stronger income make it important for sustained campaigns, especially when connected to neighboring owned regions. A Duchy is worth defending because it can keep armies supplied with men and resources over several turns.

**Province (L5)** - A Province is a mature power base. Its 8% recruit cap gives it the strongest manpower ceiling, and its resource output is the best a region can reach. Provinces are late-game assets: they help replace losses, support elite armies, and keep pressure alive after expensive battles.

Base recruit replenishment starts at 0.4% of population per turn, with +0.25% per level above L1.

### Upkeep costs from promoted regions and castles

Prosperity is not free. A larger, promoted region represents more roads, mills, storehouses, workshops, and day-to-day logistics that must be repaired and supplied. As your realm grows, basic materials become a constant requirement, not a one-time expense. Wood is the backbone of that maintenance economy.

This means rapid expansion can create a hidden pressure point: your income may look strong, but your net wood can stall or fall if too many regions are promoted before your production base catches up. Promotions are powerful, but the long war rewards players who can sustain their upkeep, not only pay for upgrades.

Region upkeep by level:

1. L1-L2: 0 Wood
2. L3: 1 Wood
3. L4: 1 Wood, 1 Stone
4. L5: 1 Food, 1 Wood, 1 Stone

Castles follow the same principle. A fortress is not only a battle asset, it is a permanent burden on your economy. Walls, gates, towers, garrisons, and supply lines all consume materials every turn. Higher-tier castles are harder to break, but they are also heavier to maintain.

If your front is wide and your castle network is deep, your wood and stone flow can be strained even when your gross income looks healthy. This is why strong players build in rhythm: secure production, then expand fortifications, then stabilize before the next wave.

Castle upkeep by tier:

1. No castle: 0 Wood, 0 Stone
2. Outpost: 2 Wood, 0 Stone
3. Keep: 2 Wood, 2 Stone
4. Castle: 2 Wood, 4 Stone
5. Stronghold: 2 Wood, 6 Stone

### When upkeep falls short

Wood and Stone shortages weaken the castles that depend on those materials. If your projected Wood or Stone balance is negative, each missing resource creates 3% of castle-defense degradation for that turn.

The penalty is distributed by upkeep. Missing Wood affects every castle that requires Wood. Missing Stone affects only castles that require Stone, so Outposts are not weakened by a Stone shortage.

For example, a 2-Stone shortage creates a 6% Stone penalty pool. With three Keeps, each Keep receives 2% degradation because they have equal Stone upkeep.

This degradation accumulates while the shortage continues. Castle defense is displayed and used in battle as a whole percentage, rounded down. Completing a repair clears the accumulated maintenance degradation.

### Difficulty and opening pressure

Starting resources change the opening tempo.

1. **Easy**: 150 Gold, 100 Food, 30 Wood, 20 Iron, 20 Stone
2. **Normal**: 100 Gold, 50 Food, 20 Wood, 10 Iron, 10 Stone
3. **Hard**: 80 Gold, 30 Food, 10 Wood, 0 Iron, 0 Stone

On harder starts, early mistakes matter more. You have less room to overspend, less food to absorb upkeep spikes, and fewer resources for immediate construction or elite recruitment.

## Recruitment and armies

### How regional recruit pools combine

Recruitment draws from the selected region and owned neighboring regions. The game does not treat each region as an isolated manpower box; it treats connected territory as a local recruitment area.

That means a castle surrounded by owned regions can recruit from a much larger pool than a lonely castle on the edge of your realm. The more owned neighbors you control around a recruitment point, the deeper that local manpower reservoir becomes. Recruits are deducted proportionally from contributing regions, so the pressure is shared across the area instead of taken from only one place.

### Recruits as local defense

Regions can defend themselves even before you manually recruit new soldiers. Available recruits fight as local Peasants when the region is attacked, so you do not need to hire every Peasant just to make a basic defense exist.

Manual recruitment still matters. If you recruit into the garrison, the recruit pool will replenish over time, while the hired garrison remains as permanent local defense. A region with both a healthy recruit pool and a built-up Peasant garrison can be much harder to storm than its army count suggests, and weak attacking armies can be driven back by local defenders alone.

### Conquest recovery and same-turn restrictions

A conquered region changes ownership immediately, but it does not become fully useful immediately. Fresh conquests need time before their population can be fully drawn into your recruitment system.

1. 0 turns owned: 0% recruit availability
2. 1 turn owned: 20%
3. 2 turns owned: 40%
4. 3 turns owned: 60%
5. 4 turns owned: 80%
6. 5+ turns owned: 100%

Newly conquered regions also cannot be fully managed on the same turn they are taken. Key actions are locked until the turn passes. This makes conquest a two-step process: first you take the land, then you consolidate it.

### Castle levels and unit access

Castles are the heart of advanced recruitment. Region levels increase recruit capacity; castle levels determine how sophisticated those recruits can become.

**No castle** - Without a castle, a region can only support the most basic recruitment. It may still contribute manpower, but it lacks the training ground, command structure, and walls needed to become a serious military center. This is enough for emergency Peasants, not for a professional army.

1. Unlocked units: Peasants

**Outpost** - An Outpost is a small defensive structure raised to protect a key region before it becomes a true fortress. It gives the defender meaningful protection and opens the first trained units, making it a practical early investment for border regions and recruitment hubs. An Outpost is still vulnerable to prepared sieges, but it changes a region from open land into a position the enemy must respect.

1. Cost: 30 Gold, 25 Wood
2. Build time: 2 turns
3. Defense: 60%, minimum 30% after structural damage
4. Walls and gates: 2 wall sections, 1 gate with 4 durability
5. Unlocked units: Peasants, Spearmen, Archers

**Keep** - A Keep is the first serious castle level. It is strong enough to anchor a frontier and broad enough to support more flexible armies. With access to Swordsmen, Crossbowmen, and Horsemen, a Keep lets you move beyond raw numbers and begin shaping armies for specific enemies and terrain.

1. Cost: 50 Gold, 15 Wood, 15 Stone
2. Build time: 2 turns
3. Defense: 70%, minimum 45% after structural damage
4. Walls and gates: 4 wall sections, 1 gate with 5 durability
5. Unlocked units: Peasants, Spearmen, Archers, Swordsmen, Crossbowmen, Horsemen

**Castle** - A Castle is a major defensive structure for important borders, rich regions, and production centers. It gives the defender high protection, two gates, thicker walls, and access to heavy troops. A well-placed Castle can survive attacks that would overwhelm a Keep and can produce armies that threaten both open-field enemies and defended positions.

1. Cost: 75 Gold, 25 Wood, 30 Stone, 10 Iron
2. Build time: 2 turns
3. Defense: 80%, minimum 50% after structural damage
4. Walls and gates: 6 wall sections, 2 gates with 6 durability each
5. Unlocked units: Peasants, Spearmen, Archers, Swordsmen, Crossbowmen, Horsemen, Knights, Mounted Knights

**Stronghold** - A Stronghold is the peak of regional military power. It is expensive, slow to prepare economically, and worth defending with everything you have. With the best defense, the most gates, the most wall sections, and access to Royal Guard, a Stronghold can survive brutal assaults and serve as the core of a late-game war machine.

1. Cost: 100 Gold, 30 Wood, 50 Stone, 20 Iron
2. Build time: 2 turns
3. Defense: 90%, minimum 60% after structural damage
4. Walls and gates: 8 wall sections, 3 gates with 7 durability each
5. Unlocked units: Peasants, Spearmen, Archers, Swordsmen, Crossbowmen, Horsemen, Knights, Mounted Knights, Royal Guard

Damaged castles can be repaired. Repair cost scales with damage as a proportion of that castle's build cost, so light damage is cheaper to fix than a heavily battered fortress. Repair is part of siege warfare: after surviving a storm, you often need resources to restore the castle before the next attack.

### Dismantling castles

A castle can be dismantled by one tier when its upkeep or position no longer justifies the investment.

1. Dismantling takes 1 turn and completes at the start of your next turn.
2. You immediately pay 25% of the current castle tier's Gold build cost.
3. When dismantling completes, you recover 25% of its Wood, Stone, and Iron build costs, rounded down.
4. An Outpost can be dismantled completely; higher tiers become the next lower tier.
5. A castle cannot be built, upgraded, or dismantled again in the same turn.

Dismantling is a way to recover part of a fortress investment and reduce future upkeep, but it also reduces defense and available unit tiers.

### Unit traits and battlefield roles

Unit traits are what make army composition more than a raw numbers contest. A force with the right traits for the terrain and opponent can outperform a larger but poorly matched army.

**Long-spears** - Spear units punish cavalry by doubling hits against mounted units. They are important when defending against Horsemen, Knights, or Mounted Knights.

**Ranged** - Ranged units can attack across the enemy line and participate in opening volleys. They are powerful before melee contact, but forests and forest hills reduce their effectiveness.

**Mobility** - Mobile units are dangerous during withdrawal because they can chase retreating troops and deal extra damage. They make retreats more costly for the enemy.

**Flanker** - Flankers can directly pressure enemy ranged units. This matters because archers and crossbowmen often rely on protection from the front line.

**Charge** - Charge units are strongest on Grassland, where they receive their major attack advantage. They lose much of their appeal if forced into rough terrain battles.

**Multi Attack** - Multi Attack represents exceptional offensive output. These units can create more pressure than their count alone suggests, especially when protected and used in decisive engagements.

**Armor Piercing** - Armor Piercing first reduces the target unit's defense by 10 percentage points, to a minimum of 0%, then halves the remaining defense. It does not reduce castle defense. Crossbowmen use this trait, so their hits are resolved separately from other units' hits.

**Siege Laborer** - Siege Laborer units generate siege points, which are required to buy ladders, rams, and trebuchets before castle assaults. Without laborers, even a large army can be poorly prepared for a siege.

**Back Rank** - Ranged units are protected from ordinary melee targeting until the attacking side has at least 3 non-ranged soldiers for every 1 non-ranged defender. Ranged attackers can always target the back rank, while Flankers ignore this ratio in open-field battles. During castle assaults, Flankers lose this exception and must obey the normal 3:1 rule.

**Defender** - Doubles the unit's attack chance when fighting on the defending side. This trait is currently assigned to Spearmen.

## Battles and sieges

### How battle resolution works turn by turn

Battles begin with 1 opening ranged volley from every ranged unit on both sides. The two sides calculate their volley hits from the same starting state, then apply casualties, so neither side loses its opportunity to fire just because the other side scored kills. After that, combat proceeds through normal rounds until one side is destroyed or withdrawal resolves.

Attacks are chance-based. Each soldier makes an attack roll using its unit attack chance. Vigor multiplies that chance: an Archer with 20% attack and 80% vigor attacks at 16%, while a Peasant with 5% attack and 80% vigor attacks at 4%. Terrain and traits can modify the result further.

Each successful attack roll creates a hit. For each attacking unit type, those hits are randomly distributed among its valid enemy targets, weighted by how many soldiers of each target type are present. A unit's defense is then its chance to avoid an assigned hit. A hit that passes every applicable defense layer kills one soldier and removes it from the battlefield.

Normal rounds are also simultaneous. Both sides calculate their attacks and casualties from the armies present at the start of the round, then both sets of kills are applied. Soldiers killed during a round therefore still make their attack rolls in that round.

### Example battle calculation

Imagine 10 Peasants and 5 Archers attacking 10 Spearmen and 5 Peasants in open terrain. The attackers have 80% vigor and the defenders have 100%.

During the opening volley, only the 5 Archers attack because the attacking Peasants are not ranged and the defenders have no ranged units. The Archers make 5 rolls at 16% each: their normal 20% attack multiplied by 80% vigor. Suppose they score 1 hit.

The defending force contains 15 soldiers: 10 Spearmen and 5 Peasants. That makes a Spearman the target with about 66.7% probability and a Peasant the target with about 33.3% probability. Suppose the hit is assigned to a Spearman. The Spearman has 25% defense, so it has a 25% chance to avoid the hit; otherwise, one Spearman is killed.

In the first normal round, suppose the 10 attacking Peasants roll at 4% and score 2 hits, while the 5 Archers roll at 16% and score 1 hit. Each unit type's hits are distributed separately among valid defenders using the same unit-count weighting. If the result assigns 1 hit to a Peasant and 2 hits to Spearmen, the Peasant has an 8% defense chance against its hit and each Spearman has a 25% defense chance against its hit.

The defenders calculate their attacks at the same time from their pre-casualty numbers. At 100% vigor, Peasants roll at their normal 5% attack. Spearmen have the Defender trait, so their normal 8% attack chance is doubled to 16%. After both armies finish calculating hits, target distribution, and defense, all casualties are applied together.

Battle results are harsh. If attackers win, defending armies, garrison, and recruits are wiped out. If defenders win, attacking armies are wiped out. If withdrawal happens, both sides keep survivors but suffer withdrawal casualties. This makes choosing the battlefield and entering with enough strength more important than simply testing an enemy position.

### Terrain effects in battle

Terrain modifies battle performance for both sides according to what is fighting there.

In Hills and Forest Hills, the attacking side takes a -20 vigor penalty. In Forest and Forest Hills, archers and crossbowmen suffer a 30% ranged effectiveness penalty. This affects whichever side is using those ranged units in that terrain. Grassland is the best ground for charge-focused cavalry, because Charge doubles attack power there.

The practical lesson is simple: do not judge a battle only by troop count. Terrain can make a strong army less efficient or turn a defensive position into a trap.

### Castle defense and siege pressure

Castle battles add two separate restrictions: assault access and castle defense. Assault access scales the attacker's non-ranged hits according to how much access ladders, destroyed walls, and broken gates provide. Ranged attacks are not reduced by assault access.

After a hit reaches a defender, castle defense provides the first chance to avoid it. Any surviving hit then faces the target unit's own defense. This is why the same garrison can be much harder to kill behind walls than in open ground.

The difference between defense values is more important than it first appears. Reducing castle defense from 50% to 40% raises the chance for a hit to pass the castle layer from 50% to 60%, which is a 20% relative increase. Reducing defense from 85% to 75% raises that pass chance from 15% to 25%, which is about a 66.7% relative increase. Trebuchet damage is therefore much more valuable against high-defense castles than the raw percentage-point change may suggest.

Structural damage changes that equation. Trebuchets can damage and breach wall sections, lowering effective castle defense and increasing assault access. Gates can be pressured by rams over battle turns; as gates take damage or fall, the assault becomes easier to sustain. Ladders improve wall access for troops trying to attack over the defenses.

Castle tiers matter because higher tiers bring more walls, stronger gates, higher defense, and higher minimum defense after damage. A Stronghold is not just a bigger number than an Outpost; it forces the attacker to solve more obstacles before the defenders can be broken.

### Siege equipment and assault planning

Siege points come from units with the Siege Laborer trait. Total siege-laborer units are divided by 10, rounded down, to determine how many siege points are available.

**Ladders** cost 1 siege point and no wood. Each ladder provides 5 points of non-ranged assault access, with a cap of 4 ladders per wall section. Assault access is those points divided by the number of non-ranged attackers. For example, 2 ladders provide 10 access points, so an army with 20 non-ranged soldiers attacks at 50% assault access before any destroyed-wall or open-gate access is added. Ladders do not reduce castle defense; they only let more melee pressure reach the defenders.

**Rams** cost 2 siege points and 2 Wood. One ram can attack each intact gate at a time, and extra rams wait in reserve until an active ram is destroyed or another intact gate needs one. A ram and its gate wear down across several battle rounds. If a gate falls, it immediately adds assault access and continues adding more access in later rounds, allowing an increasing share of the attacker's melee hits to reach the defenders.

Defending ranged units are divided across the castle's gates when ram outcomes are determined. A ram facing fewer than 10 ranged defenders has better than a 50% full-breach chance, reaching certainty if no ranged defenders cover its gate. The chance falls nonlinearly as more ranged defenders are assigned: 50% at 10, 35% at 25, 20% at 50, and 15% at 60 or more. An unsuccessful ram can still make partial progress before it is lost. Attacking several gates at once forces the defender's ranged strength to split between them, but requires multiple rams.

**Trebuchets** cost 4 siege points and 5 Wood. Each trebuchet fires 4 bombardment shots with a 50% hit chance per shot before the main battle. Successful shots damage wall sections. A damaged section removes roughly half of that castle tier's per-section defense value; a destroyed section removes the full value and adds 20 points of non-ranged assault access. Castle defense cannot be reduced below the tier's minimum defense.

A good siege plan matches equipment to the obstacle. Use trebuchets when walls and defense are the biggest obstacle. Use rams when you are willing to risk equipment for a chance to open gates and pour more soldiers into the castle. Use ladders when your army needs more direct assault access over the walls. Against serious castles, mixed preparation is often stronger than relying on one tool.

### Wounded and recovery tempo

Not every casualty becomes a permanent death. Battle losses can become wounded instead, with a base wounded chance of 30% modified by defense context. Wounded soldiers do not fight and do not consume food while wounded.

Armies heal wounded through camp actions, with a 50% heal chance for each wounded unit. Regional wounded pools mean wounded garrison soldiers and wounded recruit defenders in owned regions; these recover at the start of owned turns. Over several turns, this recovery pacing can decide whether you can continue an offensive or must pause to rebuild.

## Tips and strategy

### Choose your starting location carefully

In a skirmish game, the starting castle location can decide the shape of the whole campaign. A good start is not just the single region under the castle; it is the cluster around it. Look for several nearby regions, strong population, food access, useful local resources, and room for rapid growth.

Chokepoints matter as much as income. A rich start that is open on every side can become expensive to defend, while a slightly poorer start with mountains, forests, or narrow approaches can survive long enough to grow into a stronger position.

### Manage food before it becomes famine

When you recruit or expand, plan several turns ahead. Armies and garrisons eat every turn, so a force that looks affordable now can become a famine problem after one or two more recruitment waves. Sometimes the better choice is to recruit fewer soldiers but invest in higher-tier units that give more power for the food burden you can support.

There are exceptions. If your kingdom has huge population and deep food reserves, mass Peasant armies can overwhelm enemies by volume. Food pressure also works both ways: enemy armies need food too. Capturing or denying food regions can starve hostile forces even if you do not defeat them immediately in battle.

### Build healthy army compositions

A healthy army reflects your frontier, economy, and plan. Defensive armies benefit from spears, defenders, ranged support, and enough bodies to absorb pressure. Aggressive armies need mobility, charge power, flankers, and enough siege laborers if they are expected to attack castles.

Composition and terrain become increasingly important on higher difficulties and demanding scenarios. Raw numbers may carry an army through easier fights, but difficult battles reward matching Spearmen against cavalry, using Charge units on Grassland, protecting or flanking ranged troops, and bringing the right siege equipment for the castle tier.

Resources decide what is realistic. Wood supports archers and siege equipment. Iron supports elite troops. Food decides how many soldiers you can keep. A good composition is not the same in every kingdom; it should match what your regions can actually sustain.

### Promote and build castles with timing

Promotions are strongest when they feed a plan: grow a food base, deepen a recruitment pool, or turn a border region into a long-term supply center. Promoting everywhere without purpose can waste resources that should have become troops, castles, or siege equipment.

Castle placement and construction timing are even more dangerous. A castle under construction is an investment that has not started paying back yet, and the region can be captured before the work finishes. Build castles where you can defend the construction period, especially on borders, chokepoints, and valuable resource clusters.

When the economy turns against you, consolidation can be as important as expansion. Demote regions that no longer support your plan, or dismantle castles that you cannot maintain. A negative Wood or Stone balance does not only drain resources: it steadily weakens the defenses that depend on it.

### Think in replacement cycles

Late game is usually decided by who can replace quality losses and keep pressure alive. Stable food, high-level regions, upgraded castles, and disciplined recruitment timing matter as much as one victorious battle.
