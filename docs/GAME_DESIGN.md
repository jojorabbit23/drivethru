Core Gameplay Loop

The player is Cleatimus Maximus, a rugged mushroom farmer surviving the apocalypse by defending a fortified drive-through restaurant.

The entire game revolves around one interconnected loop:

Plain Text
Defend Shop
↓
Kill Mushroom Zombies
↓
Collect Mushroom Harvest
↓
Cook Mushroom Burgers
↓
Serve Customers
↓
Earn Cash & Tips
↓
Buy Ammo, Weapons & Upgrades
↓
Survive Harder Waves

Combat and cooking directly support each other.

Killing zombies generates mushroom ingredients.
Burgers generate most of the player's income.
Income purchases supplies, ammunition and upgrades.
Upgrades make future defense and burger production easier.

The player should constantly be deciding whether to:

Fight zombies
Repair barricades
Cook burgers
Serve customers
Defend arriving deliveries
BUILDING LAYOUT

The game takes place inside a compact fortified drive-through restaurant.

Key areas:

Plain Text
Customer Window
Grill Station
Storage Area
Supply Delivery Window
Barricaded Combat Windows
Upgrade/Shop Terminal

The building should be small enough that all stations can be reached quickly.

Players should always be able to see multiple ongoing problems at once.

COMBAT LOOP

Zombie waves attack the building from outside.

Basic flow:

Plain Text
Zombie attacks barricade
↓
Barricade breaks
↓
Zombie enters building
↓
Player must kill it

Enemy deaths produce mushroom drops.

Every kill also awards a small cash reward.

Plain Text
Basic Walker
1 Mushroom Unit
$2 Cash
 
Runner
1 Mushroom Unit
$2 Cash
 
Armored Zombie
2 Mushroom Units
$3 Cash
 
Brute
4 Mushroom Units
$5 Cash

Mushroom pickups remain available until collected and can be vacuumed through collection points near windows.

Accessibility option:

Plain Text
Auto Collect Pickups
CUSTOMER LOOP

Customers arrive at the drive-through window.

Arrival feedback:

Plain Text
Vehicle sound
Horn beep
Order notification sound
Speech bubble appears

The player does not read text orders.

Orders are communicated visually.

Examples:

Plain Text
Brown Burger Icon
= Basic Mushroom Burger
 
Blue Mushroom Burger Icon
= Blue Mushroom Patty Burger
 
Yellow Mushroom Burger Icon
= Yellow Mushroom Patty Burger
 
Double Icon
= Double Patty Burger

Customer orders appear as simple pixel-art burger icons in a speech bubble.

BURGER CREATION FLOW

The intention is to keep burger creation physical and readable while avoiding excessive busywork.

Flow:

Plain Text
Collect Mushrooms
↓
Deposit into Storage
↓
Go to Grill
↓
Select Patty Type
↓
Cook Patty
↓
Bag Burger
↓
Serve Customer
GRILL INTERACTION

When looking at the grill:

Plain Text
Press E

A simple menu appears showing available mushroom patties.

Example:

Plain Text
Common Patty x8
Blue Patty x3
Yellow Patty x2
Rare Patty x1

The player selects the desired patty.

The patty is immediately placed onto an available grill slot.

No inventory dragging.

No complex crafting UI.

COOKING STATES

Each grill slot has four states:

Plain Text
RAW
↓
COOKING
↓
READY
↓
BURNT

Prototype timings:

Plain Text
Cook Time = 6 seconds
 
Ready Window = 12 seconds
 
Burn After = 18 seconds total

Visual states:

Raw
Plain Text
Grey
No sizzle
``
Cooking
Plain Text
Sizzling
Steam
Ready
Plain Text
Golden brown
Bell sound
Ready icon
Burnt
Plain Text
Blackened
Heavy smoke

State should never rely on colour alone.

Use:

Colour
Texture
Icons
Audio
CUSTOMER SERVICE & TIPS

When a cooked burger matches the order:

Plain Text
Bag Burger
↓
Take To Window
↓
Serve
↓
Receive Payment

Customers always pay the advertised burger price if served correctly.

Tips depend on speed.

Example:

Plain Text
Burger Value = $30

Served quickly:

Plain Text
$30 + $6 Tip

Served normally:

Plain Text
$30 + $2 Tip

Served just before leaving:

Plain Text
$30

Missed order:

Plain Text
Customer leaves
No penalty
No payment

The player loses an opportunity rather than being punished.

DELIVERY SYSTEM

Deliveries provide:

Plain Text
Buns
Toppings
Cheese
Sauces
Other Non-Mushroom

Mushrooms only come from zombies.

DELIVERY DEFENSE EVENTS

Delivery enemies are separate from building attackers.

When supplies run low:

Plain Text
Delivery inbound

A supply runner appears outside carrying ingredients.

The runner approaches a designated supply window.

During this event:

Plain Text
Zombies target runner
Player must defend runner

This creates an escort/cover-fire mini event that runs independently of zombies attacking the building.

DELIVERY FLOW
Plain Text
Supplies Running Low
↓
Delivery Alert
↓
Runner Spawns
↓
Runner Approaches Building
↓
Player Defends Runner
↓
Runner Reaches Window
↓
Unload Supplies
↓
Storage Refilled
PARTIAL DELIVERY PROTECTION

Deliveries should never create unrecoverable failures.

Example:

Plain Text
20 buns incoming

If the runner is interrupted:

Plain Text
8 buns delivered
Remaining value refunded

Players always receive something.

Recovery must remain possible.

INVENTORY MODEL

Storage tracks:

Plain Text
Mushroom Units
 
Raw Patties
 
Cooked Patties
 
Buns
 
Toppings
 
Cheese
 
Special Ingredients

Mushrooms are the core production resource.

Everything else comes from deliveries.

ECONOMY STRUCTURE

Single currency:

Plain Text
Cash

Cash is used for:

Plain Text
Ammo
Weapons
Traps
Kitchen Upgrades
Building Upgrades
Supply Orders
Cosmetics

Prototype values:

Plain Text
Basic Burger = $30
 
Bun + Topping Cost = $8
 
Cheeseburger = $40
 
Cheese Cost = $3
 
Kill Reward = $2
 
24 Pistol Rounds = $12
 
12 Shotgun Shells = $30

Most income should come from burger sales.

Kill rewards provide supplemental income.

PRESSURE LOOP

At any moment the player might be dealing with:

Plain Text
Customer Waiting
Ready Patty On Grill
Burning Patty
Damaged Barricade
Incoming Zombies
Delivery Runner Under Attack
Low Ammo

The gameplay should create controlled chaos where several demands compete for attention.

The challenge is prioritization rather than raw aiming skill.

PLAYER EXPERIENCE GOAL

The game should feel like:

Plain Text
Wave Defense
+
Light Restaurant Simulator
+
Fortress Management
+
Arcade Time Management Game

The player is constantly shifting between:

Plain Text
Shooter
Cook
Mechanic
Cashier
Fortress Defender

while running the world's most ridiculous mushroom burger drive-through during the apocalypse.

FIRST PLAYABLE VERTICAL SLICE

Must support:

Plain Text
Kill Zombie
Collect Mushrooms
Store Mushrooms
Cook Patty
Serve Customer
Receive Cash
Buy Ammo
Complete Multiple Waves

After this loop feels good:

Plain Text
Add Deliveries
Add Additional Burger Types
Add Rare Mushrooms
Add Tips
Add Defended Supply Runs
Add Building Upgrades
Add Power-Ups

The entire design should prioritize readability, recoverability, and fast first-person interaction over realism or complex simulation.