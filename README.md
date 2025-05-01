# Docker Notes and Best Practices

## Where Files Are Stored When Building and Running Docker Containers

When you **build and run Docker containers**, here's where the files are saved:

### 🔹 1. **Your Project Files (like `app.js`, `Dockerfile`)**

These stay in **your local machine's folder** — wherever you created them.
Example:

```
/home/yourname/docker-node-app/      ← Your files stay here
  ├── app.js
  ├── package.json
  └── Dockerfile
```

### 🔹 2. **Docker Image**

When you run:

```bash
docker build -t my-node-app .
```

The built image is saved **inside Docker's internal storage**, not as visible files in your file system.
You can view it with:

```bash
docker images
```

It's stored in Docker's system data — on Linux, usually something like:

```
/var/lib/docker/
```

But **you should not edit files directly there**. Docker manages those files.

### 🔹 3. **Running Container**

When you run the image:

```bash
docker run -p 2000:2000 my-node-app
```

Docker starts a **container**, which is like a lightweight virtual machine.
You can see it running with:

```bash
docker ps
```

Inside the container, Docker copies the project to `/app` (as set by `WORKDIR /app` in the Dockerfile), but again, that's **inside the container** — not visible unless you "enter" it.

### 🔍 View Files Inside a Running Container

If you want to see where your files are inside the container:

```bash
docker exec -it <container_id> sh
```

Then check:

```bash
ls /app
```

Replace `<container_id>` with what you get from `docker ps`.

## Handling Dangling Images

this happens because removing an image from Docker Desktop's GUI doesn't always remove all related image layers, especially dangling or intermediate images.
The one showing as:
```
<none>        <none>    7e8cefb65b71   14 minutes ago   1.09GB
```
...is called a dangling image — it has no tag and isn't currently associated with a name or container.

### ✅ How to Safely Remove It from CLI

You can remove it with:
```bash
docker rmi 7e8cefb65b71
```

If Docker says the image is in use by a container, remove the container first:
```bash
docker ps -a           # get the container ID
docker rm <container_id>
docker rmi 7e8cefb65b71
```

### 🧹 Clean Up All Dangling Images

To remove all unused `<none>` images:
```bash
docker image prune
```

Or, to remove all unused images, containers, networks, volumes:
⚠️ Be careful — this deletes all unused Docker resources:
```bash
docker system prune -a
```

## Reducing Docker Image Size

Great observation — yes, 1.09 GB does seem large for a simple Node.js app. Let me explain why it's that big, and then how to reduce it.

### 🚨 Why is the Docker image size so large?

You're using this in your Dockerfile:
```dockerfile
FROM node:18
```
This pulls the full Node.js base image, which includes:
* Node.js runtime
* npm
* OS packages (Debian/Ubuntu base)
* Tools, docs, and more

That full image is usually ~950MB to 1.1GB.
Even if your app is tiny, Docker includes everything in the image, so the size grows fast.

### ✅ How to reduce the Docker image size

#### 🔹 Option 1: Use a smaller base image (Alpine)

Replace this line:
```dockerfile
FROM node:18
```
With this:
```dockerfile
FROM node:18-alpine
```
✅ Alpine is a minimal Linux distro (~5MB) — this can shrink your image to ~120MB.

#### 🔹 Option 2: Multi-stage builds (optional for production)

This is useful if you're compiling/building things but only need the output.
Example (not needed for your current app, but helpful later):

```dockerfile
# Build stage
FROM node:18-alpine as builder
WORKDIR /app
COPY . .
RUN npm install

# Runtime stage
FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app .
CMD ["npm", "start"]
```

#### 🔹 Option 3: Remove unnecessary files

Make sure you use .dockerignore to avoid copying things like:
Create a .dockerignore:
```
node_modules
Dockerfile
.dockerignore
.git
*.log
```
This avoids bloating your image with dev files.

### 🔄 Summary

| Tip | Impact |
|-----|--------|
| Use node:18-alpine | Reduce from ~1GB → ~120MB |
| Use .dockerignore | Avoids extra file copies |
| Use multi-stage build | Cleaner, smaller production image |

## Docker Image Storage

Docker images are stored on your system, but not in your normal project folder — they're managed internally by Docker.

### 🗂️ Where Docker Images Are Stored (By OS)

| OS | Location |
|----|----------|
| Linux | /var/lib/docker/ |
| macOS | Inside a hidden Docker VM (uses HyperKit or Colima) |
| Windows | Inside a Docker VM (WSL2 or Hyper-V) |

### 🔍 But You Should NOT Manually Touch These Folders

Docker organizes images, containers, volumes, and metadata there — changing anything manually may corrupt Docker.
Instead, use Docker CLI to manage them:
* 📦 List images: `docker images`
* 🗑️ Remove an image: `docker rmi <image_id>`
* 🔍 Inspect image details: `docker inspect <image_id>`

### 🧠 Think of Docker Images Like Virtual Machine Snapshots

They're not regular folders with files — they are layered file system snapshots. Docker mounts them when you run containers.

## Comparing Dockerfile Approaches

### 🧱 First One: Simple Single-Stage Build

```dockerfile
FROM node:18                  # Full Node.js image (~950MB)
WORKDIR /app
COPY package*.json ./
RUN npm install               # Installs dependencies
COPY . .                      # Copies your code
EXPOSE 2000
CMD ["npm", "start"]          # Starts the app
```

#### ✅ Pros:
* Simpler and good for small projects or development.
* Easy to understand and use.

#### ❌ Cons:
* Large image size (~1GB) because it includes:
    * Full OS
    * Node.js
    * npm
    * Your app
    * Source code
    * Dev dependencies (if any)
* Slightly less secure and efficient for production.

### 🏗️ Second One: Multi-Stage Build (Production-Friendly)

```dockerfile
# -------- Build Stage --------
FROM node:18-alpine as builder        # Lightweight Node image (~120MB)
WORKDIR /app
COPY . .
RUN npm install                       # Installs dependencies

# -------- Runtime Stage --------
FROM node:18-alpine                   # Starts fresh with clean image
WORKDIR /app
COPY --from=builder /app .           # Copies only built files
CMD ["npm", "start"]
```

#### ✅ Pros:
* Much smaller final image (~130MB vs 1GB)
* Keeps the final image clean — no build tools, no source code clutter.
* Better for security, performance, and CI/CD deployments.

#### ❌ Cons:
* Slightly more complex to write.
* You need to make sure everything needed at runtime is copied correctly.

### ⚖️ Summary Comparison

| Feature | Single-Stage | Multi-Stage |
|---------|--------------|-------------|
| Simplicity | ✅ Easy | ❗ Slightly advanced |
| Image Size | ❌ ~1GB | ✅ ~120MB |
| Production use | ⚠️ Not ideal | ✅ Recommended |
| Security | ❌ Less secure | ✅ Cleaner, safer |
| Dev Tools included | ✅ Yes | ❌ No (stripped out) |

## Sharing Docker Images Between PCs

To use your Docker container (or rather the Docker image) on another PC, you need to share or move the image. There are two main methods:

### 🔁 OPTION 1: Export/Import via .tar File (No Docker Hub needed)

#### ✅ On your current PC (export the image):
```bash
docker save -o my-node-app.tar my-node-app
```
This creates a file my-node-app.tar — it contains your image.
📁 You can now move this file to another PC (USB, email, network, etc.).

#### ✅ On the target PC (import the image):
Move the .tar file to the target PC, then:
```bash
docker load -i my-node-app.tar
```
Now run the container:
```bash
docker run -p 2000:2000 my-node-app
```

### 🌐 OPTION 2: Push/Pull from Docker Hub (needs internet)

If both PCs have Docker installed and Docker Hub accounts:

#### ✅ 1. Tag your image:
```bash
docker tag my-node-app yourdockerhubusername/my-node-app
```

#### ✅ 2. Push to Docker Hub:
```bash
docker push yourdockerhubusername/my-node-app
```

#### ✅ 3. On the other PC:
```bash
docker pull yourdockerhubusername/my-node-app
docker run -p 2000:2000 yourdockerhubusername/my-node-app
```
🔒 You must be logged in to Docker Hub: `docker login`

### ⚡ TL;DR

| Method | Best When | Requires Internet? |
|--------|-----------|-------------------|
| save/load | Local sharing, no internet | ❌ No |
| push/pull | Cloud access, many users | ✅ Yes |