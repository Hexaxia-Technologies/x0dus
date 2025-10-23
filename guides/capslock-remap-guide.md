# Remapping Caps Lock to an F-Key on Linux (KDE Wayland)

## Why Caps Lock is the Most Useless Key on Your Keyboard

Let's be honest: **Caps Lock is prime real estate being wasted on a feature nobody uses intentionally.** It sits in one of the most accessible positions on your keyboard - right on the home row where your pinky naturally rests - and what does it do? Makes you type in all caps. Something you need maybe 0.01% of the time, and even then, you could just hold Shift.

Meanwhile, it's one of the easiest keys to hit accidentally, leading to passwords that don't work, sentences THAT LOOK LIKE YOU'RE YELLING, and general frustration.

**So why not remap it to something actually useful?**

I remap Caps Lock to an F-key (F13-F24) because:
- **Global hotkeys**: Perfect for Push-to-Talk in Discord, OBS streaming controls, or any app-wide hotkey that shouldn't conflict with anything
- **No conflicts**: F13-F24 aren't used by games, browsers, or most software - unlike Ctrl/Alt combos that are always taken
- **Easy to reach**: It's right there on the home row. Why waste it on caps lock when it could be your most-used hotkey?
- **Works everywhere**: Once remapped at the system level, it works in every application without per-app configuration

On Windows, this is a simple registry edit. On Linux... well, that's where things get interesting.

## The Problem
Coming from Windows where you can easily remap Caps Lock to F13 via registry edits, I wanted to do the same on Linux. Sounds simple, right? Well...

**The gotchas:**
1. `xmodmap` doesn't work on Wayland (only X11)
2. **KDE secretly uses F13-F20 for system shortcuts** - but they're not labeled as F-keys in the settings!

When you browse KDE's keyboard shortcuts, you'll see things like:
- "Quick Settings"
- "Microphone Mute" 
- Various media controls

What they *don't* tell you is that these are bound to F13-F20! So when you remap Caps Lock to F13, you'll mysteriously open Quick Settings instead of triggering your Discord Push-to-Talk.

## The Solution: keyd + F20 (or higher)

### Step 1: Install keyd
`xmodmap` won't work on Wayland, so we need `keyd` - a low-level keyboard remapper that works everywhere (X11, Wayland, even TTY).

```bash
# Install dependencies
sudo apt install git build-essential

# Clone and build keyd
git clone https://github.com/rvaiya/keyd
cd keyd
make
sudo make install
```

### Step 2: Configure keyd to remap Caps Lock
```bash
# Create config directory
sudo mkdir -p /etc/keyd

# Remap Caps Lock to F20
echo -e "[ids]\n*\n\n[main]\ncapslock = f20" | sudo tee /etc/keyd/default.conf
```

**Why F20?** F13-F19 are taken by KDE. F20+ are generally safe, though you might need to check F20-F24 to find one that's not bound.

### Step 3: Enable and start keyd
```bash
sudo systemctl enable keyd
sudo systemctl start keyd
```

### Step 4: Disable KDE's conflicting shortcut
Even F20 might be bound! In my case, it was "Microphone Mute" (but labeled as such, not as F20).

1. Open **System Settings** → **Shortcuts**
2. Search for the function that's triggering (in my case "microphone mute")
3. Click the shortcut and press **Backspace** to clear it
4. Click **Apply**

### Step 5: Test it
```bash
sudo keyd monitor
```
Press Caps Lock - you should see:
```
f20 down
f20 up
```

If it still triggers a KDE function, try F21-F24 instead:
```bash
echo -e "[ids]\n*\n\n[main]\ncapslock = f21" | sudo tee /etc/keyd/default.conf
sudo systemctl restart keyd
```

### Step 6: Use it in Discord (or whatever app)
1. Open Discord Settings → Keybinds
2. Set your Push-to-Talk keybind
3. Press Caps Lock
4. Profit! 🎉

## Why This Matters
Applications like Discord, OBS, and other software often have issues recognizing common key combos when you're gaming or already holding modifier keys. Having a dedicated F13-F24 key is super useful because:
- Nothing else uses them (usually)
- They work across apps
- No conflicts with games or other software
- Much more ergonomic than reaching for actual F13-F24 keys

## TL;DR
- `xmodmap` doesn't work on Wayland
- Use `keyd` instead - it's universal
- **KDE hides F13-F20 bindings under friendly names** - check for conflicts!
- F20-F24 are your safest bet
- Disable any conflicting KDE shortcuts
- Now you have a free global hotkey in the most convenient position on your keyboard!

## System Info
- **OS:** KDE Neon (KDE Plasma 6.5)
- **Display Server:** Wayland
- **Why not X11?** Wayland is the future and generally better on modern KDE

Hope this saves someone else the headache! 🍻
