# Feedback

## Raw

```
# Tutorial problems:
# - custom properties that we want to sync through the MultiplayerSynchronizer
#   need to be exported. Not mentioned. export_custom does not work
# - How exactly the different forms of authentication work should be made clearer.
#   session IDs use your account (obiously in retrospect) and joining with the
#   same account twice (also obviously) does not work.
#   The only other way to rest Relay is to export for a web embed
#
# - I would also just generally want to know the rules of when a session ID 
#   becomes invalid (because it is removed from the Plugin Configuration tab)
# - Even if a launcher will still take a while, being able to create longer 
#   lasting / permanent session IDs or give out some kind of auth token that
#   also allows hosting sessions would be awesome

# Game Jam conclusion:
# - Ezcha is real nice, Multiplayer Nodes work, don't know about network 
#   efficiency tho
# - most addons have fuck all documentation

# Addons:
# Rapier Physics:
# - they actually are more stable than default godot physics
# - documentation is there, but by faaaar not enough for something this complex
# - I couldn't get fluids to work in the time frame I had, and it changed 
#   Rigidbody behaviour, so it was no drop-in replacement
#
# Ballistic Solutions:
# - Does what it says, little bit confusing but documentation is not bad at all
# -> Drop review
#
# Dynamic Water 2D:
# - reaction did not work, don't know why yet
# - close to every calculation of this thing is fucked up, it's a wonder it works
#   even sometimes, fuck this
# - no documentation, code from someone else?
# - no safety net against dangerous values
#
# ProtonControlAnimation:
# - Architecure and usage seemed really nice, but for some reason the last one
#   didn't work when I used 3 of them
# - Not up to date, not hugely dynamic
#
# TweenSuite:
# - way better!
# - really nice way of visually creating tweens and sequences
# - biggest issue: no way to check if tween of node is ready, the method to 
#   do that earlier triggered its own error about the delay
# -> open issue, drop a review
```

## Refined

### Ezcha Multiplayer Tutorial

- Custom properties that we want to sync through the MultiplayerSynchronizer need to be exported. `@export_storage` doesn't work either. I have looked through the docs briefly, but haven't found anything about why that is. Just looked at the repo of your tutorial and you don't export the synced properties there either, so maybe I've missed something? I get a path error when not exporting them, anyway.
- The section about the Ezcha Addon talking more about how the different forms of authentication with the Ezcha platform work would've saved me a couble hours. In retrospect, the session ID being bound to your account is incredibly obvious, but, as you know, I didn't think of it during the jam. A section about in-editor testing that has some more tips about that would be awesome. I ended up testing by running the editor on 2 laptops, using the session ID and hosting with one, and joining unauthenticated with the other. I would also really like to know how long a session ID lasts / what conditions make it invalid.
- Even if a launcher will still take a while, being able to create longer lasting / permanent session IDs or give out some kind of auth token that also allows hosting sessions would be awesome.
- My big wish for christmas (or earlier, I don't mind) is a tutorial on client side prediction and generally efficiently snychronizing physics bodies.

Game Jam conclusions:
- Yours is by far the best Godot Multiplayer tutorial I've found yet, and the problems I've had were minor (you said yourself that trying to join a lobby with the same account twice should've triggered a custom error message, and with that, it would've ben completely smooth)
- With only a little bit of previous multiplayer experience and *including* the "tries to join the same lobby with the same session ID twice" bug hunt, getting basic multiplayer up and running took me about 5 hours
- I've tried out a bunch of different addons, and learned that even the big, clean looking ones, often have fuck-all of documentation. This triggers me incredbily, because it's so damn easy to add on-engine documentation in Godot. The Ezcha Network addon is one of the rare exceptions, and I appreciate it terribly
