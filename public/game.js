// ─── Globals ────────────────────────────────────────────────
const socket = new WebSocket("ws://" + window.location.host + "/ws");
const otherPlayers = {};
let myId = null;
let scene = null;

// ─── Phaser Config ──────────────────────────────────────────
const config = {
  type: Phaser.AUTO,
  width: 800,
  height: 600,
  parent: "game-container",
  backgroundColor: "#86efac", // Lush pastel grass green
  scene: { preload, create, update },
};

const game = new Phaser.Game(config);

// ─── Scene Functions ────────────────────────────────────────
function preload() {
  // All assets are procedurally rendered for lightweight deployment
}

function create() {
  scene = this;

  // 1. Draw a beautiful whimsical cartoon land background
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
          addPlayer(id, data.x, data.y, data.color);
          count++;
        }
        updatePlayerCount(count);
        break;
      }

      case "playerJoined": {
        addPlayer(msg.id, msg.x, msg.y, msg.color);
        updatePlayerCount(Object.keys(otherPlayers).length);
        spawnMagicalStars(msg.x, msg.y, parseInt(msg.color));
        break;
      }

      case "playerMoved": {
        const entry = otherPlayers[msg.id];
        if (entry) {
          // Custom cute waddle & bounce movement tween
          const dist = Phaser.Math.Distance.Between(entry.container.x, entry.container.y, msg.x, msg.y);
          const duration = Math.max(200, Math.min(1000, dist * 1.5));

          scene.tweens.add({
            targets: entry.container,
            x: msg.x,
            y: msg.y,
            duration: duration,
            ease: "Quad.easeOut",
          });

          // Waddling rotation and bounce
          scene.tweens.add({
            targets: entry.body,
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
    }
  };

  // ── Whimsical Click-to-move ───────────────────────────────
  this.input.on("pointerdown", function (pointer) {
    if (pointer.y > 540) return; // Prevent moving when interacting with chat overlay

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
          targets: me.body,
          scaleY: 0.8,
          scaleX: 1.15,
          duration: 100,
          yoyo: true,
          repeat: Math.floor(duration / 200),
          ease: "Bounce.easeOut",
        });

        // Spawn cute star ripple
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
}

function update() {
  // No per-frame polling required
}

// ─── Drawing Background Elements ────────────────────────────
function drawCartoonBackground(scene) {
  const bg = scene.add.graphics();

  // Draw colorful whimsical fields
  bg.fillStyle(0x4ade80, 1); // lighter grass
  bg.fillCircle(150, 400, 300);
  bg.fillCircle(650, 480, 250);

  // Whimsical yellow cobblestone paths
  bg.fillStyle(0xfef08a, 0.4);
  bg.fillEllipse(400, 420, 250, 110);
  bg.fillStyle(0xfef08a, 0.6);
  bg.fillEllipse(400, 420, 220, 90);

  // Draw cute path cobblestones
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

  // Draw whimsical trees
  drawCuteTree(scene, 80, 150, 0x16a34a, 0x15803d);
  drawCuteTree(scene, 720, 180, 0x22c55e, 0x16a34a);
}

// Draw a cute whimsical cartoon mushroom
function drawCuteMushrooms(scene, x, y) {
  const g = scene.add.graphics();
  // Stem
  g.fillStyle(0xffedd5, 1);
  g.fillRoundedRect(x - 6, y, 12, 22, 6);
  // Cap
  g.fillStyle(0xef4444, 1); // bright red cap
  g.fillEllipse(x, y + 2, 28, 18);
  // Cap dots
  g.fillStyle(0xffffff, 1);
  g.fillCircle(x - 5, y - 1, 3);
  g.fillCircle(x + 5, y + 2, 2.5);
  g.fillCircle(x, y - 4, 3);
}

// Draw a cartoon style tree
function drawCuteTree(scene, x, y, primaryColor, darkColor) {
  const g = scene.add.graphics();
  // Trunk
  g.fillStyle(0x78350f, 1);
  g.fillRoundedRect(x - 8, y, 16, 80, 6);

  // Fluffy leaf layers
  g.fillStyle(darkColor, 1);
  g.fillCircle(x, y + 5, 45);
  g.fillStyle(primaryColor, 1);
  g.fillCircle(x, y - 10, 40);
  
  // Highlight
  g.fillStyle(0x86efac, 0.4);
  g.fillCircle(x - 12, y - 22, 16);
}

// ─── Creating a Cute Character Container ────────────────────
function addPlayer(id, x, y, colorStr) {
  if (otherPlayers[id]) return;

  const color = parseInt(colorStr);
  const container = scene.add.container(x, y);
  
  // Character body - cute wobbly jelly capsule
  const body = scene.add.graphics();
  body.fillStyle(color, 1);
  body.fillRoundedRect(-20, -25, 40, 50, 18); // soft capsule
  body.lineStyle(3, 0xffffff, 1);
  body.strokeRoundedRect(-20, -25, 40, 50, 18);

  // Cute big anime-style eyes
  const eyeL = scene.add.circle(-8, -8, 6, 0xffffff);
  const pupilL = scene.add.circle(-8, -8, 3, 0x000000);
  const pupilHighlightL = scene.add.circle(-9, -9, 1, 0xffffff);

  const eyeR = scene.add.circle(8, -8, 6, 0xffffff);
  const pupilR = scene.add.circle(8, -8, 3, 0x000000);
  const pupilHighlightR = scene.add.circle(7, -9, 1, 0xffffff);

  // Rosy cute cheeks
  const cheekL = scene.add.circle(-13, 2, 4, 0xfca5a5, 0.7);
  const cheekR = scene.add.circle(13, 2, 4, 0xfca5a5, 0.7);

  // Small smiley mouth
  const mouth = scene.add.graphics();
  mouth.lineStyle(2, 0x000000, 0.8);
  mouth.beginPath();
  mouth.arc(0, 0, 4, 0, Math.PI, false);
  mouth.strokePath();

  // Floating shadow
  const shadow = scene.add.graphics();
  shadow.fillStyle(0x000000, 0.15);
  shadow.fillEllipse(0, 28, 22, 6);
  container.add(shadow);

  // Add parts to container
  container.add(body);
  container.add(eyeL);
  container.add(pupilL);
  container.add(pupilHighlightL);
  container.add(eyeR);
  container.add(pupilR);
  container.add(pupilHighlightR);
  container.add(cheekL);
  container.add(cheekR);
  container.add(mouth);

  // Gentle float animation
  scene.tweens.add({
    targets: [body, eyeL, pupilL, pupilHighlightL, eyeR, pupilR, pupilHighlightR, cheekL, cheekR, mouth],
    y: "-=3",
    duration: 1000 + Math.random() * 400,
    yoyo: true,
    repeat: -1,
    ease: "Sine.easeInOut",
  });

  // Name Tag
  const isMe = id === myId;
  const shortId = id.substring(0, 5);
  const label = isMe ? "You!" : `Builder ${shortId}`;
  
  const nameTagBg = scene.add.graphics();
  nameTagBg.fillStyle(0xffffff, 0.95);
  nameTagBg.lineStyle(2, color, 1);
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

  otherPlayers[id] = { container, body, nameTag };
}

// Remove Player
function removePlayer(id) {
  const entry = otherPlayers[id];
  if (!entry) return;
  
  // Custom exit poof particles
  spawnMagicalStars(entry.container.x, entry.container.y, 0xef4444);
  entry.container.destroy();
  delete otherPlayers[id];
}

// ─── Helper: Whimsical Comic Speech Bubble ──────────────────
function showChatBubble(id, message) {
  const entry = otherPlayers[id];
  if (!entry) return;

  // Destroy previous bubble if exists
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

  // Procedural speech bubble container with pointer tail
  const bubbleBg = scene.add.graphics();
  // Border
  bubbleBg.lineStyle(3, 0x1e293b, 1);
  bubbleBg.fillStyle(0xffffff, 1);
  
  // Draw bubble body
  bubbleBg.fillRoundedRect(-width / 2, -height - 58, width, height, 14);
  bubbleBg.strokeRoundedRect(-width / 2, -height - 58, width, height, 14);

  // Draw talk triangle tail
  bubbleBg.beginPath();
  bubbleBg.moveTo(-6, -58);
  bubbleBg.lineTo(0, -48);
  bubbleBg.lineTo(6, -58);
  bubbleBg.closePath();
  bubbleBg.fillPath();
  bubbleBg.strokePath();

  // Position text inside bubble
  bubbleText.setPosition(-width / 2 + 12, -height - 50);

  const bubbleGroup = scene.add.container(entry.container.x, entry.container.y);
  bubbleGroup.add(bubbleBg);
  bubbleGroup.add(bubbleText);
  bubbleGroup.setDepth(20);

  // Link bubble to player so it tracks them if they move
  entry.chatBubble = bubbleGroup;

  // Track parent updates in Phaser tween updates
  const tween = scene.tweens.add({
    targets: bubbleGroup,
    x: {
      getStart: () => entry.container.x,
      getEnd: () => entry.container.x
    },
    y: {
      getStart: () => entry.container.y,
      getEnd: () => entry.container.y
    },
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

// ─── Whimsical Star Particle Burst ──────────────────────────
function spawnMagicalStars(x, y, color) {
  for (let i = 0; i < 10; i++) {
    // draw a simple star shape or colored circle with phaser
    const star = scene.add.graphics();
    star.fillStyle(0xfde047, 1); // bright yellow star elements
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
      rotation: 2,
      duration: 600,
      ease: "Power2",
      onComplete: () => star.destroy(),
    });
  }
}

// ─── Cute Click Ripple ──────────────────────────────────────
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

// ─── Helper: Update Player count ────────────────────────────
function updatePlayerCount(count) {
  const badge = document.getElementById("player-count");
  if (badge) {
    badge.textContent = `${count} ${count === 1 ? "builder" : "builders"} online`;
  }
}
