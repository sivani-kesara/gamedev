import json
import uuid
import random
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.staticfiles import StaticFiles

app = FastAPI()

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


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()

    client_id = str(uuid.uuid4())
    color = random_color()
    
    # Initialize with default look matching Secret Builders options
    players[client_id] = {
        "x": 400,
        "y": 300,
        "color": color,
        "name": f"Builder_{client_id[:5]}",
        "mood": "is happy",
        "hair": "emo_black",
        "hat": "cap_sb",
        "outfit": "collared_tie",
        "back": "skateboard",
        "aura": "grass",
        "days": random.randint(10, 1500),
        "level": random.randint(1, 40)
    }
    
    connected_clients.append((client_id, websocket))

    # Broadcast to ALL that a new player joined
    await broadcast({
        "type": "playerJoined",
        "id": client_id,
        "player": players[client_id]
    })

    # Send the new client the full current state
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

            if action == "move":
                new_x = data["x"]
                new_y = data["y"]
                if client_id in players:
                    players[client_id]["x"] = new_x
                    players[client_id]["y"] = new_y
                await broadcast({
                    "type": "playerMoved",
                    "id": client_id,
                    "x": new_x,
                    "y": new_y,
                })

            elif action == "chat":
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
                        "aura": data.get("aura", players[client_id].get("aura")),
                        "mood": data.get("mood", players[client_id].get("mood")),
                        "color": data.get("color", players[client_id].get("color")),
                        "name": data.get("name", players[client_id].get("name")),
                        "skin": data.get("skin", players[client_id].get("skin")),
                    })
                await broadcast({
                    "type": "playerCustomized",
                    "id": client_id,
                    "player": players[client_id]
                })

    except WebSocketDisconnect:
        pass
    except Exception:
        pass
    finally:
        connected_clients[:] = [
            (cid, ws) for cid, ws in connected_clients if cid != client_id
        ]
        players.pop(client_id, None)
        await broadcast({
            "type": "playerLeft",
            "id": client_id,
        })


# Mount static files LAST so the /ws route takes priority
app.mount("/", StaticFiles(directory="public", html=True), name="static")
