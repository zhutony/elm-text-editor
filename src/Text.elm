module Text exposing (jabberwocky, alphabet, testString, news, tolstoy)

news = """The siege by supporters of an Iranian-backed militia at the U.S. Embassy in Baghdad ended Wednesday after the militia ordered them to withdraw, bringing relief to the diplomats trapped inside and averting a potential showdown between the United States and Iran.

Supporters of the Kataib Hezbollah militia who had spent the night camped outside the embassy dismantled their tents and marched out of the area, saying they would instead continue to press for the withdrawal of U.S. troops from Iraq in the nation’s parliament.

“Yay! We burned them!” they chanted as they headed away from the embassy, a reference to the fires set by the demonstrators that burned two embassy reception areas Tuesday.
"""


tolstoy = """“Well, Prince, so Genoa and Lucca are now just family
estates of the Buonapartes. But I warn you, if you don’t
tell me that this means war, if you still try to defend
the infamies and horrors perpetrated by that Antichrist—
I really believe he is Antichrist—I will have nothing
more to do with you and you are no longer my friend,
no longer my ‘faithful slave,’ as you call yourself!
But how do you do? I see I have frightened you—
sit down and tell me all the news.
 ”"""


testString = """This is a first test of how
the editor could be used as a package.
The 'Test' is a proxy for loading new
content into the editor from an external
source.

The API will change a lot as I experiment
with it.  The goal is to have as few
exposed functions as possible.

Everything in the 0.5 px bordered region
you see here comes from Editor code.  All
the rest (below, beginning with "Source ...")
is from the code in Main.

"""

alphabet = """1
2
3
4
5
6
7
8
9
10
a
b
c
d
e
f
g
h
i
j
k
l
m
n
o
p
q
r
s
t
u
v
w
x
y
z

"""

jabberwocky = """Jabberwocky

By Lewis Carroll

’Twas brillig, and the slithy toves
     Did gyre and gimble in the wabe:
All mimsy were the borogoves,
     And the mome raths outgrabe.

“Beware the Jabberwock, my son!
     The jaws that bite, the claws that catch!
Beware the Jubjub bird, and shun
     The frumious Bandersnatch!”

He took his vorpal sword in hand;
     Long time the manxome foe he sought—
So rested he by the Tumtum tree
     And stood awhile in thought.

And, as in uffish thought he stood,
     The Jabberwock, with eyes of flame,
Came whiffling through the tulgey wood,
     And burbled as it came!

One, two! One, two! And through and through
     The vorpal blade went snicker-snack!
He left it dead, and with its head
     He went galumphing back.

“And hast thou slain the Jabberwock?
     Come to my arms, my beamish boy!
O frabjous day! Callooh! Callay!”
     He chortled in his joy.

’Twas brillig, and the slithy toves
     Did gyre and gimble in the wabe:
All mimsy were the borogoves,
     And the mome raths outgrabe.

PS. Here is the buried treasure.

NOTES

1. The above text about "treasure" is **fake**.
We were just testing to see if we could send
the editor requests like "find the word 'treasure,'
scroll down to it, and highlight it."

2. Now that this is working, we have a bit of
code cleanup to do. And more work on some
cursor and highight flakines, e.g., highlighting
should be preserved when scrolling.


"""


