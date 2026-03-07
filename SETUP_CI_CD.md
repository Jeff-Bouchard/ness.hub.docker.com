# 🚀 Next 24 Hours: Enable Automated Adoption

This is your action plan. Three steps. One hour total.

## Step 1: Generate Docker Hub Token (10 minutes)

1. Go to: https://hub.docker.com/settings/security
2. Click "New Access Token" (Personal Access)
3. Name it: `github-ness-ci`
4. Permissions: `Read, Write, Delete`
5. Copy the token (you'll only see it once)

---

## Step 2: Add GitHub Secrets (5 minutes)

1. Go to: https://github.com/Jeff-Bouchard/ness.hub.docker.com/settings/secrets/actions
2. Click "New repository secret"
3. **Secret 1:**
   - Name: `DOCKER_HUB_USERNAME`
   - Value: `nessnetwork` (or your Docker Hub org name)
   - Click "Add secret"

4. **Secret 2:**
   - Name: `DOCKER_HUB_TOKEN`
   - Value: Paste the token from Step 1
   - Click "Add secret"

**Verify:** You should now see two secrets listed on that page.

---

## Step 3: Test the CI/CD Pipeline (5 minutes)

```bash
cd ness.hub.docker.com

# Create a release tag
git tag v0.1.0 -a -m "First automated release"

# Push the tag (this triggers CI/CD)
git push origin v0.1.0

# Watch the build
# Go to: https://github.com/Jeff-Bouchard/ness.hub.docker.com/actions
```

**Expected:**
- 9 images × 3 architectures = 27 parallel builds
- Takes 15-30 minutes (first build is slowest)
- All should pass with "✓"

---

## Step 4: Verify Images Pushed (10 minutes after builds complete)

```bash
# Test pull the multi-arch image
docker pull nessnetwork/emercoin-core:v0.1.0

# Verify on different arch
docker run --platform linux/arm64 nessnetwork/emercoin-core:v0.1.0 --version
docker run --platform linux/amd64 nessnetwork/emercoin-core:v0.1.0 --version
```

If both work → **CI/CD is working perfectly**.

---

## If Something Fails

**Build failed?** Check the logs:
1. Go to Actions tab
2. Click the failed build
3. Expand the failed step
4. Check error message
5. Common fixes:
   - Missing `DOCKER_HUB_TOKEN` secret
   - Invalid credentials
   - Docker Hub org doesn't exist yet

**Images not on Docker Hub?** 
- Verify secrets are set correctly
- Rerun the workflow manually (click "Run workflow" button)

---

## What Happens Next (Automatic)

After this one-time setup, here's the flow:

```
You: git tag v0.1.1
You: git push origin v0.1.1
     ↓
GitHub Actions: Detects tag
     ↓
GitHub Actions: Builds 27 images (all archs)
     ↓
GitHub Actions: Pushes to nessnetwork/* on Docker Hub
     ↓
You: Don't do anything
     ↓
Next user: docker pull nessnetwork/emercoin-core
           Gets the latest build automatically
```

**No more manual** `docker build` and `docker push`. It's automatic.

---

## Then What?

Once images are on Docker Hub, users can:

```bash
# Easy one-liner deployment
bash <(curl -fsSL https://get.ness-network.org/quick-start)
```

This script will:
1. Clone your repo
2. Pull images from Docker Hub (super fast)
3. Start the stack
4. Show running services

---

## Success Checkpoint

After completing all steps, you should have:

- [x] Two GitHub secrets set (DOCKER_HUB_USERNAME, DOCKER_HUB_TOKEN)
- [x] First v0.1.0 tag pushed and built
- [x] 27 images built successfully (9 images × 3 archs)
- [x] Images visible on Docker Hub at `docker.io/nessnetwork/*:v0.1.0`
- [x] Able to pull and run images locally

---

## Your Next 3 Weeks

| Timeline | What | Why |
|----------|------|-----|
| **Now** | Enable CI/CD | Automate everything |
| **Day 2** | Test quick-start.sh | Verify user experience |
| **Day 7** | First community feedback | Iterate on docs |
| **Week 2** | Add Umbrel integration | Reach Home Automation users |
| **Week 3** | First 10 active nodes | Proof of adoption |

---

## Questions?

Read these files for more context:
- `QUICK_START.md` — What users will experience
- `DEPLOYMENT_CHECKLIST.md` — Full roadmap (phases 1-6)
- `ADOPTION_SUMMARY.md` — What was built and why

---

**You're 1 hour away from automated adoption infrastructure.**

Let me know once you've completed these steps and I'll help troubleshoot any CI/CD issues.
