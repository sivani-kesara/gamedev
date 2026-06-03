import json
import uuid
import random
import sqlite3
import bcrypt
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.staticfiles import StaticFiles
from contextlib import asynccontextmanager

def init_db():
    conn = sqlite3.connect("players.db")
    c = conn.cursor()
    try:
        # Check if table exists and has the new columns
        c.execute("SELECT hair FROM users LIMIT 1")
    except sqlite3.OperationalError:
        # Drop and recreate if old schema or doesn't exist
        c.execute("DROP TABLE IF EXISTS users")
        c.execute('''
            CREATE TABLE IF NOT EXISTS users (
                username TEXT PRIMARY KEY,
                password_hash TEXT,
                hair TEXT,
                hat TEXT,
                outfit TEXT,
                back TEXT,
                skin_color TEXT,
                mood TEXT
            )
        ''')
        conn.commit()
    conn.close()

@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    yield

app = FastAPI(lifespan=lifespan)

players: dict = {}
connected_clients: list[tuple[str, WebSocket]] = []

async def broadcast(message: dict):
    """Send a JSON message to every connected client."""
    payload = json.dumps(message)
    disconnected = []
    for client_id, ws in connected_clients:
        try:
            await ws.send_text(payload)
        except Exception:
            disconnected.append((client_id, ws))
    for item in disconnected:
        connected_clients.remove(item)

def random_color() -> str:
    """Return a random hex color string like '0xRRGGBB'."""
    r = random.randint(40, 220)
    g = random.randint(40, 220)
    b = random.randint(40, 220)
    return f"0x{r:02x}{g:02x}{b:02x}"

def make_avatar_dict(username: str, hair: str, hat: str, outfit: str, back: str, skin_color: str, mood: str) -> dict:
    return {
        "x": 360,
        "y": 640,
        "color": random_color(),
        "name": username,
        "mood": mood,
        "hair": hair,
        "hat": hat,
        "outfit": outfit,
        "back": back,
        "skin_color": skin_color,
        "days": random.randint(10, 1500),
        "level": random.randint(1, 40)
    }

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()

    client_id = str(uuid.uuid4())
    connected_clients.append((client_id, websocket))

    # Send the new client the full current state of players
    await websocket.send_text(json.dumps({
        "type": "init",
        "id": client_id,
        "players": players,
    }))

    try:
        while True:
            raw = await websocket.receive_text()
            data = json.loads(raw)
            action = data.get("action")

            if action == "signup":
                username = data.get("username", "").strip()
                password = data.get("password", "")
                if not username or not password:
                    await websocket.send_text(json.dumps({"type": "auth_error", "message": "Missing fields"}))
                    continue
                
                conn = sqlite3.connect("players.db")
                c = conn.cursor()
                c.execute("SELECT username FROM users WHERE username=?", (username,))
                if c.fetchone():
                    conn.close()
                    await websocket.send_text(json.dumps({"type": "auth_error", "message": "Username taken"}))
                else:
                    hashed = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
                    c.execute("""
                        INSERT INTO users (username, password_hash, hair, hat, outfit, back, skin_color, mood)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """, (username, hashed, "emo_black", "cap_sb", "collared_tie", "skateboard", "fbcfe8", "is happy"))
                    conn.commit()
                    conn.close()
                    
                    avatar_data = make_avatar_dict(username, "emo_black", "cap_sb", "collared_tie", "skateboard", "fbcfe8", "is happy")
                    players[client_id] = avatar_data
                    await websocket.send_text(json.dumps({"type": "auth_success", "avatar_data": avatar_data}))
                    await broadcast({"type": "playerJoined", "id": client_id, "player": avatar_data})

            elif action == "login":
                username = data.get("username", "").strip()
                password = data.get("password", "")
                if not username or not password:
                    await websocket.send_text(json.dumps({"type": "auth_error", "message": "Missing fields"}))
                    continue
                
                conn = sqlite3.connect("players.db")
                c = conn.cursor()
                c.execute("""
                    SELECT password_hash, hair, hat, outfit, back, skin_color, mood
                    FROM users WHERE username=?
                """, (username,))
                row = c.fetchone()
                conn.close()

                if not row:
                    await websocket.send_text(json.dumps({"type": "auth_error", "message": "User not found"}))
                else:
                    stored_hash = row[0].encode('utf-8')
                    if bcrypt.checkpw(password.encode('utf-8'), stored_hash):
                        avatar_data = make_avatar_dict(
                            username,
                            row[1], # hair
                            row[2], # hat
                            row[3], # outfit
                            row[4], # back
                            row[5], # skin_color
                            row[6], # mood
                        )
                        players[client_id] = avatar_data
                        await websocket.send_text(json.dumps({"type": "auth_success", "avatar_data": avatar_data}))
                        await broadcast({"type": "playerJoined", "id": client_id, "player": avatar_data})
                    else:
                        await websocket.send_text(json.dumps({"type": "auth_error", "message": "Wrong password"}))

            elif action == "move":
                if client_id in players:
                    new_x = data["x"]
                    new_y = data["y"]
                    players[client_id]["x"] = new_x
                    players[client_id]["y"] = new_y
                    await broadcast({
                        "type": "playerMoved",
                        "id": client_id,
                        "x": new_x,
                        "y": new_y,
                    })

            elif action == "chat":
                if client_id in players:
                    message = data.get("message", "")
                    await broadcast({
                        "type": "playerChat",
                        "id": client_id,
                        "message": message,
                    })

            elif action == "customize":
                if client_id in players:
                    players[client_id].update({
                        "hair": data.get("hair", players[client_id].get("hair")),
                        "hat": data.get("hat", players[client_id].get("hat")),
                        "outfit": data.get("outfit", players[client_id].get("outfit")),
                        "back": data.get("back", players[client_id].get("back")),
                        "skin_color": data.get("skin_color", players[client_id].get("skin_color")),
                        "mood": data.get("mood", players[client_id].get("mood")),
                        "name": data.get("name", players[client_id].get("name")),
                        "color": data.get("color", players[client_id].get("color")),
                    })
                    
                    # Persist changes to SQLite
                    username = players[client_id].get("name")
                    if username:
                        conn = sqlite3.connect("players.db")
                        c = conn.cursor()
                        c.execute("""
                            UPDATE users
                            SET hair=?, hat=?, outfit=?, back=?, skin_color=?, mood=?
                            WHERE username=?
                        """, (
                            players[client_id].get("hair"),
                            players[client_id].get("hat"),
                            players[client_id].get("outfit"),
                            players[client_id].get("back"),
                            players[client_id].get("skin_color"),
                            players[client_id].get("mood"),
                            username
                        ))
                        conn.commit()
                        conn.close()

                    await broadcast({
                        "type": "playerCustomized",
                        "id": client_id,
                        "player": players[client_id]
                    })

    except WebSocketDisconnect:
        pass
    except Exception as e:
        print(f"Error: {e}")
    finally:
        connected_clients[:] = [
            (cid, ws) for cid, ws in connected_clients if cid != client_id
        ]
        if client_id in players:
            players.pop(client_id, None)
            await broadcast({
                "type": "playerLeft",
                "id": client_id,
            })

# Mount static files LAST so the /ws route takes priority
app.mount("/", StaticFiles(directory="public", html=True), name="static")
