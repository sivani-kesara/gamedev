// ─── Globals ────────────────────────────────────────────────
let host = window.location.host;
if (host.includes("51921") || host.includes("5500") || host.includes("5173") || host.includes("3000") || host.includes("8080")) {
    host = "localhost:8000";
}
const socket = new WebSocket("ws://" + host + "/ws");
const otherPlayers = {};
let myId = null;
let scene = null;

// Default configuration options for customization
const CUSTOM_ITEMS = {
  hair: [
    { id: "none", name: "No Hair", color: 0x000000, desc: "Sleek & Bald" },
    { id: "emo_black", name: "Emo Fringe", color: 0x1e293b, desc: "Sweeping black locks" },
    { id: "wavy_gold", name: "Golden Curls", color: 0xeab308, desc: "Flowing wavy blonde hair" },
    { id: "punk_pink", name: "Punk Spikes", color: 0xec4899, desc: "Bright spiky pink hair" },
    { id: "cozy_brown", name: "Cozy Cut", color: 0x78350f, desc: "Soft brown casual hair" }
  ],
  hat: [
    { id: "none", name: "No Hat", desc: "Keep it simple" },
    { id: "cap_sb", name: "SB Flatcap", desc: "Signature grey SB cap" },
    { id: "newsboy", name: "Newsboy Cap", desc: "Textured grey cap" },
    { id: "wizard", name: "Wizard Hat", desc: "Magical purple hat" },
    { id: "crown", name: "Royal Crown", desc: "Shiny gold with ruby gems" }
  ],
  outfit: [
    { id: "none", name: "Simple Suit", desc: "Casual look" },
    { id: "collared_tie", name: "Collared Shirt & Tie", desc: "Fancy school/office look" },
    { id: "wedding_gown", name: "Bridal Gown", desc: "Elegant white dress with a rose" },
    { id: "green_hoodie", name: "Green Hoodie", desc: "Comfy gamer attire" },
    { id: "cool_jacket", name: "Leather Jacket", desc: "Rockstar black biker jacket" }
  ],
  back: [
    { id: "none", name: "No Item", desc: "Travel light" },
    { id: "skateboard", name: "Red Skateboard", desc: "Cool ride carried on back" },
    { id: "wings", name: "Angel Wings", desc: "Soft glowing white wings" },
    { id: "wand", name: "Magic Wand", desc: "Holds a sparkly gold wand" }
  ],
  skin: [
    { id: "default", name: "Peach Skin", color: "0xfbcfe8" },
    { id: "sky", name: "Sky Blue", color: "0xbae6fd" },
    { id: "lime", name: "Lime Green", color: "0xc7d2fe" },
    { id: "gold", name: "Golden Glow", color: "0xfef08a" }
  ]
};

// Player's local customized state
let myProfile = {
  hair: "emo_black",
  hat: "cap_sb",
  outfit: "collared_tie",
  back: "skateboard",
  color: "0xfbcfe8",
  mood: "is happy"
};

// ─── Phaser Config ──────────────────────────────────────────
const config = {
  type: Phaser.AUTO,
  scale: {
    mode: Phaser.Scale.FIT,
    autoCenter: Phaser.Scale.CENTER_BOTH,
    parent: "game-container",
    width: 800,
    height: 600
  },
  backgroundColor: "#86efac", // Lush pastel grass green
  scene: { preload, create, update },
};

const game = new Phaser.Game(config);

function preload() {}

function create() {
  scene = this;

  // Draw background hills, trails, mushrooms, and trees
  drawCartoonBackground(this);

  // ── WebSocket Handlers ────────────────────────────────────
  socket.onmessage = (event) => {
    const msg = JSON.parse(event.data);

    switch (msg.type) {
      case "init": {
        myId = msg.id;
        const playerMap = msg.players;
        let count = 0;
        for (const [id, data] of Object.entries(playerMap)) {
          addPlayer(id, data);
          count++;
        }
        updatePlayerCount(count);

        // Load local profile data
        if (playerMap[myId]) {
          myProfile = {
            hair: playerMap[myId].hair,
            hat: playerMap[myId].hat,
            outfit: playerMap[myId].outfit,
            back: playerMap[myId].back,
            color: playerMap[myId].color,
            mood: playerMap[myId].mood,
            name: playerMap[myId].name,
            days: playerMap[myId].days,
            level: playerMap[myId].level
          };
          renderHTMLPreview();
        }
        break;
      }

      case "playerJoined": {
        addPlayer(msg.id, msg.player);
        updatePlayerCount(Object.keys(otherPlayers).length);
        spawnMagicalStars(msg.player.x, msg.player.y, parseInt(msg.player.color));
        break;
      }

      case "playerMoved": {
        const entry = otherPlayers[msg.id];
        if (entry) {
          const dist = Phaser.Math.Distance.Between(entry.container.x, entry.container.y, msg.x, msg.y);
          const duration = Math.max(200, Math.min(1000, dist * 1.5));

          scene.tweens.add({
            targets: entry.container,
            x: msg.x,
            y: msg.y,
            duration: duration,
            ease: "Quad.easeOut",
          });

          // Waddle animation
          scene.tweens.add({
            targets: entry.bodyGroup,
            scaleY: 0.8,
            scaleX: 1.15,
            duration: 100,
            yoyo: true,
            repeat: Math.floor(duration / 200),
            ease: "Bounce.easeOut",
          });
        }
        break;
      }

      case "playerLeft": {
        removePlayer(msg.id);
        updatePlayerCount(Object.keys(otherPlayers).length);
        break;
      }

      case "playerChat": {
        showChatBubble(msg.id, msg.message);
        break;
      }

      case "playerCustomized": {
        const entry = otherPlayers[msg.id];
        if (entry) {
          // Re-draw their look procedurally!
          redrawPlayerLook(msg.id, msg.player);
          // Spawn little sparkles
          spawnMagicalStars(entry.container.x, entry.container.y, parseInt(msg.player.color));
        }
        break;
      }
    }
  };

  // ── Click-to-move ─────────────────────────────────────────
  this.input.on("pointerdown", function (pointer) {
    if (pointer.y > 540) return; // Ignore clicks near chat bar

    // Also check if user clicked on another player to view their profile card!
    let clickedPlayer = null;
    for (const [id, entry] of Object.entries(otherPlayers)) {
      const dist = Phaser.Math.Distance.Between(entry.container.x, entry.container.y, pointer.x, pointer.y);
      if (dist < 40) {
        clickedPlayer = id;
        break;
      }
    }

    if (clickedPlayer) {
      openPlayerProfile(clickedPlayer);
      return;
    }

    if (socket.readyState === WebSocket.OPEN) {
      socket.send(
        JSON.stringify({ action: "move", x: pointer.x, y: pointer.y })
      );

      // Optimistic local move
      const me = otherPlayers[myId];
      if (me) {
        const dist = Phaser.Math.Distance.Between(me.container.x, me.container.y, pointer.x, pointer.y);
        const duration = Math.max(200, Math.min(1000, dist * 1.5));
        
        scene.tweens.add({
          targets: me.container,
          x: pointer.x,
          y: pointer.y,
          duration: duration,
          ease: "Quad.easeOut",
        });

        scene.tweens.add({
          targets: me.bodyGroup,
          scaleY: 0.8,
          scaleX: 1.15,
          duration: 100,
          yoyo: true,
          repeat: Math.floor(duration / 200),
          ease: "Bounce.easeOut",
        });

        spawnStarRipple(pointer.x, pointer.y);
      }
    }
  });

  // ── Chat logic ────────────────────────────────────────────
  const chatInput = document.getElementById("chatInput");
  const chatBtn = document.getElementById("chatSendBtn");

  function sendChat() {
    const text = chatInput.value.trim();
    if (!text) return;
    if (socket.readyState === WebSocket.OPEN) {
      socket.send(JSON.stringify({ action: "chat", message: text }));
    }
    chatInput.value = "";
  }

  chatBtn.addEventListener("click", sendChat);
  chatInput.addEventListener("keydown", (e) => {
    if (e.key === "Enter") sendChat();
  });

  // Setup HTML HUD & Customizer Listeners
  setupHTMLUI();
}

function update() {}

// ─── Drawing Background Elements ────────────────────────────
function drawCartoonBackground(scene) {
  const bg = scene.add.graphics();

  // Draw colorful whimsical fields
  bg.fillStyle(0x4ade80, 1);
  bg.fillCircle(150, 400, 300);
  bg.fillCircle(650, 480, 250);

  // Yellow paths
  bg.fillStyle(0xfef08a, 0.4);
  bg.fillEllipse(400, 420, 250, 110);
  bg.fillStyle(0xfef08a, 0.6);
  bg.fillEllipse(400, 420, 220, 90);

  bg.fillStyle(0xfde047, 0.7);
  for (let i = 0; i < 15; i++) {
    const cx = 250 + Math.random() * 300;
    const cy = 370 + Math.random() * 100;
    bg.fillCircle(cx, cy, 6 + Math.random() * 8);
  }

  // Draw mushrooms
  drawCuteMushrooms(scene, 120, 300);
  drawCuteMushrooms(scene, 680, 260);
  drawCuteMushrooms(scene, 220, 480);
  drawCuteMushrooms(scene, 580, 490);

  // Draw trees
  drawCuteTree(scene, 80, 150, 0x16a34a, 0x15803d);
  drawCuteTree(scene, 720, 180, 0x22c55e, 0x16a34a);
}

function drawCuteMushrooms(scene, x, y) {
  const g = scene.add.graphics();
  g.fillStyle(0xffedd5, 1);
  g.fillRoundedRect(x - 6, y, 12, 22, 6);
  g.fillStyle(0xef4444, 1);
  g.fillEllipse(x, y + 2, 28, 18);
  g.fillStyle(0xffffff, 1);
  g.fillCircle(x - 5, y - 1, 3);
  g.fillCircle(x + 5, y + 2, 2.5);
  g.fillCircle(x, y - 4, 3);
}

function drawCuteTree(scene, x, y, primaryColor, darkColor) {
  const g = scene.add.graphics();
  g.fillStyle(0x78350f, 1);
  g.fillRoundedRect(x - 8, y, 16, 80, 6);
  g.fillStyle(darkColor, 1);
  g.fillCircle(x, y + 5, 45);
  g.fillStyle(primaryColor, 1);
  g.fillCircle(x, y - 10, 40);
  g.fillStyle(0x86efac, 0.4);
  g.fillCircle(x - 12, y - 22, 16);
}

// ─── Procedural Character Drawer ────────────────────────────
function drawCharacterParts(g, data) {
  g.clear();
  const color = parseInt(data.color);

  // 1. Draw Back/Held item (skateboard / wings etc.) underneath the body
  if (data.back === "skateboard") {
    g.fillStyle(0xd97706, 1);
    g.fillEllipse(-26, 4, 12, 45);
    g.fillStyle(0xef4444, 1);
    g.fillEllipse(-26, 4, 8, 41);
    g.fillStyle(0x475569, 1);
    g.fillCircle(-32, -10, 5);
    g.fillCircle(-32, 18, 5);
  } else if (data.back === "wings") {
    g.fillStyle(0xffffff, 0.85);
    g.lineStyle(2, 0xe2e8f0, 1);
    g.fillEllipse(-28, -6, 24, 14, 0.3);
    g.strokeEllipse(-28, -6, 24, 14, 0.3);
    g.fillEllipse(28, -6, 24, 14, -0.3);
    g.strokeEllipse(28, -6, 24, 14, -0.3);
  }

  // 2. Humanoid Body Base
  // Legs
  g.fillStyle(color, 1);
  g.fillRoundedRect(-10, 10, 8, 15, 4);
  g.fillRoundedRect(2, 10, 8, 15, 4);
  g.lineStyle(2, 0xffffff, 1);
  g.strokeRoundedRect(-10, 10, 8, 15, 4);
  g.strokeRoundedRect(2, 10, 8, 15, 4);

  // Arms
  g.fillStyle(color, 1);
  g.fillRoundedRect(-20, -6, 8, 20, 4);
  g.fillRoundedRect(12, -6, 8, 20, 4);
  g.strokeRoundedRect(-20, -6, 8, 20, 4);
  g.strokeRoundedRect(12, -6, 8, 20, 4);

  // Torso
  g.fillStyle(color, 1);
  g.fillRoundedRect(-12, -8, 24, 26, 8);
  g.strokeRoundedRect(-12, -8, 24, 26, 8);

  // Head
  g.fillStyle(color, 1);
  g.fillCircle(0, -22, 15);
  g.strokeCircle(0, -22, 15);

  // 3. Outfits
  if (data.outfit === "collared_tie") {
    g.fillStyle(0xffffff, 1);
    g.fillRoundedRect(-12, -8, 24, 26, 4);
    g.fillRoundedRect(-20, -6, 8, 20, 4);
    g.fillRoundedRect(12, -6, 8, 20, 4);
    g.fillStyle(0x1e293b, 1);
    g.fillRoundedRect(-2.5, -6, 5, 16, 1.5);
  } else if (data.outfit === "wedding_gown") {
    g.fillStyle(0xffffff, 0.95);
    g.fillRoundedRect(-12, -8, 24, 20, 4);
    g.fillRoundedRect(-18, 10, 36, 15, 6);
    g.fillRoundedRect(-20, -6, 8, 15, 4);
    g.fillRoundedRect(12, -6, 8, 15, 4);
    g.fillStyle(0xec4899, 1);
    g.fillCircle(0, 0, 4);
  } else if (data.outfit === "green_hoodie") {
    g.fillStyle(0x22c55e, 1);
    g.fillRoundedRect(-13, -9, 26, 28, 6);
    g.fillRoundedRect(-21, -6, 10, 21, 4);
    g.fillRoundedRect(11, -6, 10, 21, 4);
    g.lineStyle(2.5, 0xffffff, 0.95);
    g.lineBetween(-4, -2, -4, 8);
    g.lineBetween(4, -2, 4, 8);
  } else if (data.outfit === "cool_jacket") {
    g.fillStyle(0x1e293b, 1);
    g.fillRoundedRect(-13, -9, 26, 27, 4);
    g.fillRoundedRect(-21, -6, 10, 21, 4);
    g.fillRoundedRect(11, -6, 10, 21, 4);
    g.fillStyle(0xef4444, 1);
    g.fillTriangle(-6, -8, 6, -8, 0, 4);
  }

  // 4. Eyes
  g.fillStyle(0xffffff, 1);
  g.fillCircle(-6, -24, 4.5);
  g.fillCircle(6, -24, 4.5);
  g.fillStyle(0x000000, 1);
  g.fillCircle(-6, -24, 2);
  g.fillCircle(6, -24, 2);
  g.fillStyle(0xffffff, 1);
  g.fillCircle(-7, -25, 1);
  g.fillCircle(5, -25, 1);

  // 5. Cheeks & mouth
  g.fillStyle(0xfca5a5, 0.7);
  g.fillCircle(-10, -18, 3);
  g.fillCircle(10, -18, 3);
  g.lineStyle(1.5, 0x000000, 0.8);
  g.beginPath();
  g.arc(0, -18, 3, 0, Math.PI, false);
  g.strokePath();

  // 6. Hair
  if (data.hair === "emo_black") {
    g.fillStyle(0x1e293b, 1);
    g.beginPath();
    g.moveTo(-16, -37);
    g.quadraticCurveTo(-5, -42, 14, -30);
    g.lineTo(10, -22);
    g.quadraticCurveTo(-4, -28, -14, -21);
    g.closePath();
    g.fillPath();
  } else if (data.hair === "wavy_gold") {
    g.fillStyle(0xfacc15, 1);
    g.fillCircle(-16, -22, 6);
    g.fillCircle(-17, -14, 5);
    g.fillCircle(16, -22, 6);
    g.fillCircle(17, -14, 5);
    g.fillEllipse(0, -36, 16, 8);
  } else if (data.hair === "punk_pink") {
    g.fillStyle(0xec4899, 1);
    g.fillTriangle(-16, -32, -8, -46, -2, -34);
    g.fillTriangle(-6, -34, 2, -49, 10, -34);
    g.fillTriangle(6, -34, 14, -46, 16, -32);
  } else if (data.hair === "cozy_brown") {
    g.fillStyle(0x78350f, 1);
    g.fillEllipse(0, -36, 17, 8);
    g.fillCircle(-15, -28, 5);
    g.fillCircle(15, -28, 5);
  }

  // 7. Hats (drawn on top of hair)
  if (data.hat === "cap_sb") {
    g.fillStyle(0x475569, 1);
    g.fillEllipse(0, -38, 16, 9);
    g.fillStyle(0x1e293b, 1);
    g.fillRoundedRect(-22, -36, 16, 4, 2);
    g.fillStyle(0xfacc15, 1);
    g.fillCircle(0, -37, 3);
  } else if (data.hat === "newsboy") {
    g.fillStyle(0x64748b, 1);
    g.fillEllipse(0, -38, 18, 8);
    g.fillStyle(0x475569, 1);
    g.fillEllipse(0, -34, 19, 3);
  } else if (data.hat === "wizard") {
    g.fillStyle(0x6366f1, 1);
    g.fillTriangle(-18, -34, 18, -34, 0, -60);
    g.fillStyle(0x4f46e5, 1);
    g.fillEllipse(0, -34, 20, 4);
    g.fillStyle(0xfacc15, 1);
    g.fillCircle(0, -48, 3);
  } else if (data.hat === "crown") {
    g.fillStyle(0xeab308, 1);
    g.beginPath();
    g.moveTo(-14, -34);
    g.lineTo(-12, -46);
    g.lineTo(-6, -38);
    g.lineTo(0, -50);
    g.lineTo(6, -38);
    g.lineTo(12, -46);
    g.lineTo(14, -34);
    g.closePath();
    g.fillPath();
    g.fillStyle(0xef4444, 1);
    g.fillCircle(0, -49, 2);
    g.fillCircle(-12, -45, 1.5);
    g.fillCircle(12, -45, 1.5);
  }

  // 8. Magic Wand held in hand (right side)
  if (data.back === "wand") {
    g.lineStyle(2.5, 0x78350f, 1);
    g.lineBetween(16, 6, 28, -12);
    g.fillStyle(0xfacc15, 1);
    g.fillCircle(28, -12, 5.5);
  }
}

// ─── Add Player into Phaser Scene ───────────────────────────
function addPlayer(id, data) {
  if (otherPlayers[id]) return;

  const container = scene.add.container(data.x, data.y);
  container.setDepth(5);

  // Separate waddling group for physics bounces
  const bodyGroup = scene.add.container(0, 0);
  container.add(bodyGroup);

  const characterGraphics = scene.add.graphics();
  bodyGroup.add(characterGraphics);

  // Soft shadow underneath waddles
  const shadow = scene.add.graphics();
  shadow.fillStyle(0x000000, 0.15);
  shadow.fillEllipse(0, 28, 22, 6);
  container.add(shadow);

  // Floating idle loop
  scene.tweens.add({
    targets: bodyGroup,
    y: "-=3",
    duration: 1000 + Math.random() * 400,
    yoyo: true,
    repeat: -1,
    ease: "Sine.easeInOut",
  });

  // Name Tag box
  const isMe = id === myId;
  const label = isMe ? "You!" : data.name;
  
  const nameTagBg = scene.add.graphics();
  nameTagBg.fillStyle(0xffffff, 0.95);
  nameTagBg.lineStyle(2, parseInt(data.color), 1);
  nameTagBg.fillRoundedRect(-45, -46, 90, 18, 9);
  nameTagBg.strokeRoundedRect(-45, -46, 90, 18, 9);
  container.add(nameTagBg);

  const nameTag = scene.add.text(0, -37, label, {
    fontFamily: "Fredoka, sans-serif",
    fontSize: "11px",
    fontWeight: "700",
    color: isMe ? "#db2777" : "#0f172a",
  });
  nameTag.setOrigin(0.5);
  container.add(nameTag);

  otherPlayers[id] = { container, bodyGroup, graphics: characterGraphics, nameTag, data };

  // Draw actual looks procedural
  drawCharacterParts(characterGraphics, data);
}

// Re-draw player visual assets
function redrawPlayerLook(id, data) {
  const entry = otherPlayers[id];
  if (!entry) return;
  entry.data = data;
  drawCharacterParts(entry.graphics, data);
}

// Remove Player
function removePlayer(id) {
  const entry = otherPlayers[id];
  if (!entry) return;
  spawnMagicalStars(entry.container.x, entry.container.y, 0xef4444);
  entry.container.destroy();
  delete otherPlayers[id];
}

// ─── Whimsical Comic Speech Bubble ──────────────────
function showChatBubble(id, message) {
  const entry = otherPlayers[id];
  if (!entry) return;

  if (entry.chatBubble) {
    entry.chatBubble.destroy();
  }

  const bubbleText = scene.add.text(0, 0, message, {
    fontFamily: "Fredoka, sans-serif",
    fontSize: "13px",
    fontWeight: "600",
    color: "#1e293b",
    padding: { x: 12, y: 8 },
    wordWrap: { width: 160 },
  });

  const width = Math.max(60, bubbleText.width + 24);
  const height = bubbleText.height + 16;

  const bubbleBg = scene.add.graphics();
  bubbleBg.lineStyle(3, 0x1e293b, 1);
  bubbleBg.fillStyle(0xffffff, 1);
  bubbleBg.fillRoundedRect(-width / 2, -height - 58, width, height, 14);
  bubbleBg.strokeRoundedRect(-width / 2, -height - 58, width, height, 14);

  bubbleBg.beginPath();
  bubbleBg.moveTo(-6, -58);
  bubbleBg.lineTo(0, -48);
  bubbleBg.lineTo(6, -58);
  bubbleBg.closePath();
  bubbleBg.fillPath();
  bubbleBg.strokePath();

  bubbleText.setPosition(-width / 2 + 12, -height - 50);

  const bubbleGroup = scene.add.container(entry.container.x, entry.container.y);
  bubbleGroup.add(bubbleBg);
  bubbleGroup.add(bubbleText);
  bubbleGroup.setDepth(20);

  entry.chatBubble = bubbleGroup;

  scene.tweens.add({
    targets: bubbleGroup,
    x: { getStart: () => entry.container.x, getEnd: () => entry.container.x },
    y: { getStart: () => entry.container.y, getEnd: () => entry.container.y },
    duration: 4000,
    onUpdate: () => {
      if (entry.container && bubbleGroup) {
        bubbleGroup.x = entry.container.x;
        bubbleGroup.y = entry.container.y;
      }
    },
    onComplete: () => {
      scene.tweens.add({
        targets: bubbleGroup,
        alpha: 0,
        y: "-=20",
        duration: 250,
        onComplete: () => {
          bubbleGroup.destroy();
          if (entry.chatBubble === bubbleGroup) {
            entry.chatBubble = null;
          }
        }
      });
    }
  });
}

// ─── Sparkle particles ──────────────────────────────────────
function spawnMagicalStars(x, y, color) {
  for (let i = 0; i < 10; i++) {
    const star = scene.add.graphics();
    star.fillStyle(0xfde047, 1);
    star.fillCircle(x, y, Phaser.Math.Between(3, 7));
    star.setDepth(15);

    const angle = (Math.PI * 2 * i) / 10 + Math.random() * 0.5;
    const dist = Phaser.Math.Between(40, 80);

    scene.tweens.add({
      targets: star,
      x: x + Math.cos(angle) * dist,
      y: y + Math.sin(angle) * dist,
      alpha: 0,
      scaleX: 0,
      scaleY: 0,
      duration: 600,
      ease: "Power2",
      onComplete: () => star.destroy(),
    });
  }
}

function spawnStarRipple(x, y) {
  for (let i = 0; i < 5; i++) {
    const star = scene.add.text(x, y, "★", {
      fontSize: Phaser.Math.Between(16, 26) + "px",
      color: ["#facc15", "#f472b6", "#60a5fa", "#34d399"][Math.floor(Math.random() * 4)],
    });
    star.setOrigin(0.5);
    star.setAngle(Math.random() * 360);

    const angle = Math.random() * Math.PI * 2;
    const dist = Phaser.Math.Between(20, 50);

    scene.tweens.add({
      targets: star,
      x: x + Math.cos(angle) * dist,
      y: y + Math.sin(angle) * dist,
      alpha: 0,
      scaleX: 0.1,
      scaleY: 0.1,
      angle: "+=180",
      duration: 500,
      ease: "Quad.easeOut",
      onComplete: () => star.destroy(),
    });
  }
}

function updatePlayerCount(count) {
  const badge = document.getElementById("player-count");
  if (badge) {
    badge.textContent = `${count} ${count === 1 ? "builder" : "builders"} online`;
  }
}

// ─── Customizer HTML UI & Profile Integration ────────────────
let selectedTab = "hair";
let viewingPlayerId = null;

function setupHTMLUI() {
  const myProfileBtn = document.getElementById("my-profile-btn");
  const profileModal = document.getElementById("profile-modal");
  const profileCloseBtn = document.getElementById("profile-close-btn");
  const triggerCustomizerBtn = document.getElementById("trigger-customizer-btn");
  const customizerModal = document.getElementById("customizer-modal");
  const customizerCloseBtn = document.getElementById("customizer-close-btn");
  const saveLookBtn = document.getElementById("save-look-btn");
  const moodDropdown = document.getElementById("profile-mood");

  // Open MY profile
  myProfileBtn.addEventListener("click", () => {
    openPlayerProfile(myId);
  });

  profileCloseBtn.addEventListener("click", () => {
    profileModal.style.display = "none";
  });

  customizerCloseBtn.addEventListener("click", () => {
    customizerModal.style.display = "none";
  });

  // Open customizer
  triggerCustomizerBtn.addEventListener("click", () => {
    profileModal.style.display = "none";
    customizerModal.style.display = "flex";
    renderCustomizerGrid();
  });

  // Tabs navigation
  document.querySelectorAll(".tab-btn").forEach((btn) => {
    btn.addEventListener("click", (e) => {
      document.querySelectorAll(".tab-btn").forEach((b) => b.classList.remove("active"));
      e.target.classList.add("active");
      selectedTab = e.target.getAttribute("data-tab");
      renderCustomizerGrid();
    });
  });

  // Save looks perfect
  saveLookBtn.addEventListener("click", () => {
    customizerModal.style.display = "none";
    
    // Send look customization to server
    if (socket.readyState === WebSocket.OPEN) {
      socket.send(JSON.stringify({
        action: "customize",
        hair: myProfile.hair,
        hat: myProfile.hat,
        outfit: myProfile.outfit,
        back: myProfile.back,
        color: myProfile.color,
        mood: myProfile.mood
      }));
    }
  });

  // Mood selector change
  moodDropdown.addEventListener("change", (e) => {
    myProfile.mood = e.target.value;
    if (socket.readyState === WebSocket.OPEN) {
      socket.send(JSON.stringify({
        action: "customize",
        mood: myProfile.mood
      }));
    }
  });
}

// Open the profile card for a specific player (can be "you" or another builder)
function openPlayerProfile(id) {
  viewingPlayerId = id;
  const modal = document.getElementById("profile-modal");
  const data = id === myId ? myProfile : otherPlayers[id]?.data;

  if (!data) return;

  // Set titles & credentials
  document.getElementById("profile-name").textContent = id === myId ? "You!" : data.name;
  
  const moodDropdown = document.getElementById("profile-mood");
  moodDropdown.value = data.mood || "is happy";
  
  // Disable mood editing if viewing another player
  moodDropdown.disabled = id !== myId;

  // Change look visibility
  const triggerCustomizerBtn = document.getElementById("trigger-customizer-btn");
  triggerCustomizerBtn.style.display = id === myId ? "block" : "none";

  // XP, Days, Level setup
  document.getElementById("profile-xp").textContent = data.xp || 895;
  document.getElementById("profile-days").textContent = data.days || 426;
  document.getElementById("profile-level").textContent = data.level || 5;

  modal.style.display = "flex";

  // Render the detailed avatar preview in the HTML canvas
  renderHTMLPreview(data);
}

// Render HTML Canvas avatar preview in card
function renderHTMLPreview(playerData) {
  const canvas = document.getElementById("preview-canvas");
  if (!canvas) return;
  const ctx = canvas.getContext("2d");
  
  // Set dimensions
  canvas.width = 280;
  canvas.height = 240;

  const data = playerData || myProfile;

  // Draw background matching selected mood/aura
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  
  // Background radial blue magical pattern
  const grad = ctx.createRadialGradient(140, 120, 20, 140, 120, 180);
  grad.addColorStop(0, "#bae6fd");
  grad.addColorStop(1, "#38bdf8");
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  // Draw background particles / sparkles
  ctx.fillStyle = "rgba(255,255,255,0.4)";
  for (let i = 0; i < 6; i++) {
    ctx.beginPath();
    ctx.arc(40 + i * 40 + Math.sin(i) * 10, 60 + Math.cos(i) * 30, 4 + (i%3), 0, Math.PI * 2);
    ctx.fill();
  }

  // Draw player shadow
  ctx.fillStyle = "rgba(0,0,0,0.12)";
  ctx.beginPath();
  ctx.ellipse(140, 195, 45, 12, 0, 0, Math.PI * 2);
  ctx.fill();

  // Draw the customizer avatar procedurally at large scale (x3 size scale!)
  ctx.save();
  ctx.translate(140, 115);
  ctx.scale(2.5, 2.5); // Blow up character detail

  const color = parseInt(data.color || "0xfbcfe8");

  // 1. Skateboard/Back items
  if (data.back === "skateboard") {
    ctx.fillStyle = "#d97706";
    ctx.beginPath();
    ctx.ellipse(-26, 4, 6, 22, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#ef4444";
    ctx.beginPath();
    ctx.ellipse(-26, 4, 4, 20, 0, 0, Math.PI * 2);
    ctx.fill();
  } else if (data.back === "wings") {
    ctx.fillStyle = "rgba(255,255,255,0.9)";
    ctx.strokeStyle = "#cbd5e1";
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.ellipse(-28, -6, 12, 7, 0.3, 0, Math.PI * 2);
    ctx.fill(); ctx.stroke();
    ctx.beginPath();
    ctx.ellipse(28, -6, 12, 7, -0.3, 0, Math.PI * 2);
    ctx.fill(); ctx.stroke();
  }

  // 2. Base Body
  ctx.fillStyle = "#" + color.toString(16).padStart(6, '0');
  ctx.strokeStyle = "#ffffff";
  ctx.lineWidth = 2.5;
  // Legs
  drawRoundedRect(ctx, -10, 10, 8, 15, 4); ctx.fill(); ctx.stroke();
  drawRoundedRect(ctx, 2, 10, 8, 15, 4); ctx.fill(); ctx.stroke();
  // Arms
  drawRoundedRect(ctx, -20, -6, 8, 20, 4); ctx.fill(); ctx.stroke();
  drawRoundedRect(ctx, 12, -6, 8, 20, 4); ctx.fill(); ctx.stroke();
  // Torso
  drawRoundedRect(ctx, -12, -8, 24, 26, 8); ctx.fill(); ctx.stroke();
  // Head
  ctx.beginPath(); ctx.arc(0, -22, 15, 0, Math.PI * 2); ctx.fill(); ctx.stroke();

  // 3. Dress Outfit
  if (data.outfit === "collared_tie") {
    ctx.fillStyle = "#ffffff";
    drawRoundedRect(ctx, -12, -8, 24, 26, 4); ctx.fill();
    drawRoundedRect(ctx, -20, -6, 8, 20, 4); ctx.fill();
    drawRoundedRect(ctx, 12, -6, 8, 20, 4); ctx.fill();
    ctx.fillStyle = "#1e293b";
    drawRoundedRect(ctx, -2.5, -6, 5, 16, 1.5); ctx.fill();
  } else if (data.outfit === "wedding_gown") {
    ctx.fillStyle = "#ffffff";
    drawRoundedRect(ctx, -12, -8, 24, 20, 4); ctx.fill();
    drawRoundedRect(ctx, -18, 10, 36, 15, 6); ctx.fill();
    drawRoundedRect(ctx, -20, -6, 8, 15, 4); ctx.fill();
    drawRoundedRect(ctx, 12, -6, 8, 15, 4); ctx.fill();
    ctx.fillStyle = "#ec4899";
    ctx.beginPath(); ctx.arc(0, 0, 4, 0, Math.PI*2); ctx.fill();
  } else if (data.outfit === "green_hoodie") {
    ctx.fillStyle = "#22c55e";
    drawRoundedRect(ctx, -13, -9, 26, 28, 6); ctx.fill();
    drawRoundedRect(ctx, -21, -6, 10, 21, 4); ctx.fill();
    drawRoundedRect(ctx, 11, -6, 10, 21, 4); ctx.fill();
  } else if (data.outfit === "cool_jacket") {
    ctx.fillStyle = "#1e293b";
    drawRoundedRect(ctx, -13, -9, 26, 27, 4); ctx.fill();
    drawRoundedRect(ctx, -21, -6, 10, 21, 4); ctx.fill();
    drawRoundedRect(ctx, 11, -6, 10, 21, 4); ctx.fill();
    ctx.fillStyle = "#ef4444";
    ctx.beginPath(); ctx.moveTo(-6,-8); ctx.lineTo(6,-8); ctx.lineTo(0,4); ctx.closePath(); ctx.fill();
  }

  // 4. Eyes
  ctx.fillStyle = "#ffffff";
  ctx.beginPath(); ctx.arc(-6, -24, 4.5, 0, Math.PI*2); ctx.fill();
  ctx.beginPath(); ctx.arc(6, -24, 4.5, 0, Math.PI*2); ctx.fill();
  ctx.fillStyle = "#000000";
  ctx.beginPath(); ctx.arc(-6, -24, 2, 0, Math.PI*2); ctx.fill();
  ctx.beginPath(); ctx.arc(6, -24, 2, 0, Math.PI*2); ctx.fill();
  ctx.fillStyle = "#ffffff";
  ctx.beginPath(); ctx.arc(-7, -25, 1, 0, Math.PI*2); ctx.fill();
  ctx.beginPath(); ctx.arc(5, -25, 1, 0, Math.PI*2); ctx.fill();

  // Rosy cheeks
  ctx.fillStyle = "rgba(252,165,165,0.7)";
  ctx.beginPath(); ctx.arc(-10, -18, 3, 0, Math.PI*2); ctx.fill();
  ctx.beginPath(); ctx.arc(10, -18, 3, 0, Math.PI*2); ctx.fill();

  // Smile
  ctx.strokeStyle = "rgba(0,0,0,0.8)";
  ctx.lineWidth = 1.5;
  ctx.beginPath();
  ctx.arc(0, -18, 3, 0, Math.PI);
  ctx.stroke();

  // 5. Hair (scaled up)
  if (data.hair === "emo_black") {
    ctx.fillStyle = "#1e293b";
    ctx.beginPath();
    ctx.moveTo(-16, -37);
    ctx.quadraticCurveTo(-5, -42, 14, -30);
    ctx.lineTo(10, -22);
    ctx.quadraticCurveTo(-4, -28, -14, -21);
    ctx.closePath();
    ctx.fill();
  } else if (data.hair === "wavy_gold") {
    ctx.fillStyle = "#facc15";
    ctx.beginPath(); ctx.arc(-16, -22, 6, 0, Math.PI*2); ctx.fill();
    ctx.beginPath(); ctx.arc(-17, -14, 5, 0, Math.PI*2); ctx.fill();
    ctx.beginPath(); ctx.arc(16, -22, 6, 0, Math.PI*2); ctx.fill();
    ctx.beginPath(); ctx.arc(17, -14, 5, 0, Math.PI*2); ctx.fill();
    ctx.beginPath(); ctx.ellipse(0, -36, 16, 8, 0, 0, Math.PI*2); ctx.fill();
  } else if (data.hair === "punk_pink") {
    ctx.fillStyle = "#ec4899";
    // left spike
    ctx.beginPath(); ctx.moveTo(-16, -32); ctx.lineTo(-8, -46); ctx.lineTo(-2, -34); ctx.closePath(); ctx.fill();
    // mid spike
    ctx.beginPath(); ctx.moveTo(-6, -34); ctx.lineTo(2, -49); ctx.lineTo(10, -34); ctx.closePath(); ctx.fill();
    // right spike
    ctx.beginPath(); ctx.moveTo(6, -34); ctx.lineTo(14, -46); ctx.lineTo(16, -32); ctx.closePath(); ctx.fill();
  } else if (data.hair === "cozy_brown") {
    ctx.fillStyle = "#78350f";
    ctx.beginPath(); ctx.ellipse(0, -36, 17, 8, 0, 0, Math.PI*2); ctx.fill();
    ctx.beginPath(); ctx.arc(-15, -28, 5, 0, Math.PI*2); ctx.fill();
    ctx.beginPath(); ctx.arc(15, -28, 5, 0, Math.PI*2); ctx.fill();
  }

  // 6. Hats
  if (data.hat === "cap_sb") {
    ctx.fillStyle = "#475569";
    ctx.beginPath(); ctx.ellipse(0, -38, 16, 9, 0, 0, Math.PI*2); ctx.fill();
    ctx.fillStyle = "#1e293b";
    drawRoundedRect(ctx, -22, -36, 16, 4, 2);
    ctx.fill();
    ctx.fillStyle = "#facc15";
    ctx.beginPath(); ctx.arc(0, -37, 3, 0, Math.PI*2); ctx.fill();
  } else if (data.hat === "newsboy") {
    ctx.fillStyle = "#64748b";
    ctx.beginPath(); ctx.ellipse(0, -38, 18, 8, 0, 0, Math.PI*2); ctx.fill();
    ctx.fillStyle = "#475569";
    ctx.beginPath(); ctx.ellipse(0, -34, 19, 3, 0, 0, Math.PI*2); ctx.fill();
  } else if (data.hat === "wizard") {
    ctx.fillStyle = "#6366f1";
    ctx.beginPath();
    ctx.moveTo(-18, -34); ctx.lineTo(18, -34); ctx.lineTo(0, -60);
    ctx.closePath();
    ctx.fill();
    // rim
    ctx.fillStyle = "#4f46e5";
    ctx.beginPath(); ctx.ellipse(0, -34, 20, 4, 0, 0, Math.PI*2); ctx.fill();
  } else if (data.hat === "crown") {
    ctx.fillStyle = "#eab308";
    ctx.beginPath();
    ctx.moveTo(-14, -34); ctx.lineTo(-12, -46); ctx.lineTo(-6, -38); ctx.lineTo(0, -50); ctx.lineTo(6, -38); ctx.lineTo(12, -46); ctx.lineTo(14, -34);
    ctx.closePath();
    ctx.fill();
  }

  // 7. Magic wand
  if (data.back === "wand") {
    ctx.strokeStyle = "#78350f";
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    ctx.moveTo(16, 6);
    ctx.lineTo(28, -12);
    ctx.stroke();
    ctx.fillStyle = "#facc15";
    ctx.beginPath();
    ctx.arc(28, -12, 5.5, 0, Math.PI*2);
    ctx.fill();
  }

  ctx.restore();
}

function drawRoundedRect(ctx, x, y, width, height, radius) {
  ctx.beginPath();
  ctx.moveTo(x + radius, y);
  ctx.lineTo(x + width - radius, y);
  ctx.quadraticCurveTo(x + width, y, x + width, y + radius);
  ctx.lineTo(x + width, y + height - radius);
  ctx.quadraticCurveTo(x + width, y + height, x + width - radius, y + height);
  ctx.lineTo(x + radius, y + height);
  ctx.quadraticCurveTo(x, y + height, x, y + height - radius);
  ctx.lineTo(x, y + radius);
  ctx.quadraticCurveTo(x, y, x + radius, y);
  ctx.closePath();
}

// ─── Render Customizer Items Grid ───────────────────────────
function renderCustomizerGrid() {
  const grid = document.getElementById("items-grid");
  if (!grid) return;
  grid.innerHTML = "";

  const items = CUSTOM_ITEMS[selectedTab];
  if (!items) return;

  items.forEach((item) => {
    const card = document.createElement("div");
    card.classList.add("custom-item-card");

    // Match if currently equipped
    const isEquipped = myProfile[selectedTab] === item.id || (selectedTab === "skin" && myProfile.color === item.color);
    if (isEquipped) {
      card.classList.add("active");
    }

    // Small thumbnail text or procedural rendering
    const preview = document.createElement("div");
    preview.classList.add("custom-item-preview");
    
    if (selectedTab === "skin") {
      preview.style.background = "#" + item.color.substring(2);
      preview.style.borderRadius = "50%";
      preview.style.width = "32px";
      preview.style.height = "32px";
      preview.style.border = "3px solid #713f12";
    } else {
      // Just showing visual tags for tabs
      preview.textContent = "⭐";
      preview.style.fontSize = "24px";
    }

    const label = document.createElement("div");
    label.classList.add("item-label");
    label.textContent = item.name;

    card.appendChild(preview);
    card.appendChild(label);

    card.addEventListener("click", () => {
      // Set look locally
      if (selectedTab === "skin") {
        myProfile.color = item.color;
      } else {
        myProfile[selectedTab] = item.id;
      }

      // Re-highlight active looks
      document.querySelectorAll(".custom-item-card").forEach((c) => c.classList.remove("active"));
      card.classList.add("active");

      // Instantly redraw locally in the main game!
      const me = otherPlayers[myId];
      if (me) {
        redrawPlayerLook(myId, myProfile);
      }
    });

    grid.appendChild(card);
  });
}
