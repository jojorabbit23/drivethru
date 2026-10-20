# Customer order readability

Customer speech cards now have a larger burger, an explicit BROWN / BLUE / RED
BURGER heading, a border/tail using the existing ingredient colour, and an always
visible quantity. Quantity still reports the unserved remainder. The entire card
faces the viewer so icon and text offsets do not overlap from the hatch. Its
height was lowered to keep the heading below the serving-hatch lintel. Patience
bar and payment/order logic are unchanged.

Verified all 24 suites, import, touched-script parsing, and native Vulkan captures
of all three colours through the hatch. The capture also asserts remaining counts.
Required kitchen/serving/pistol/knife/pump captures were rendered and inspected.
Use the owner-confirmed Try_DriveThru_Vulkan.cmd launcher; it loads this same
project. No renderer switch is made by the speech-card code.
