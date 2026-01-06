# Vendor Directory Migration

## Important Note About the Vendor Directory

This repository contains an old `vendor/` directory from the original govend-based dependency management. With the migration to Go modules (`go.mod`), this directory is **no longer needed** and can be removed.

## What Changed

**Before (2018)**:
- Dependencies managed with `vendor.yml` and `govend`
- All dependencies stored in `vendor/` directory
- Repository size: ~50 MB with vendored dependencies

**After (2026)**:
- Dependencies managed with `go.mod` and Go modules
- No vendor directory needed (dependencies downloaded on-demand)
- Repository size: ~2 MB without vendor directory

## Removing the Vendor Directory

If you want to remove the old vendor directory:

```bash
# Option 1: Delete vendor directory (safe, can restore from git)
rm -rf vendor/

# Option 2: Keep vendor directory but use go.mod
# Build with -mod=mod flag (already done in Makefile)
go build -mod=mod -o bin/invoicer .
```

## Why Keep It (Optional)

You might want to keep the vendor directory if:
1. **Air-gapped environments**: Building without internet access
2. **Reproducibility**: Exact dependency versions locked
3. **Historical reference**: See what dependencies were used originally

## Using Vendor with Go Modules (Optional)

If you want to vendor with Go modules:

```bash
# Create new vendor directory with Go modules
go mod vendor

# Build using vendor
go build -mod=vendor -o bin/invoicer .
```

This will create a vendor directory managed by Go modules (different from the old govend vendor).

## Current Build Configuration

The Makefile and Dockerfile have been updated to work **without** the vendor directory:

**Makefile**:
```makefile
build:
    go build -o bin/invoicer .
```

**Dockerfile**:
```dockerfile
COPY go.mod go.sum* ./
RUN go mod download
```

## Recommendation

For modern development:
- ✅ **Remove the old vendor directory** - it's not needed
- ✅ **Use go.mod** - standard dependency management
- ✅ **Let Go download dependencies** - faster and cleaner

For production environments that require vendoring:
- ✅ **Run `go mod vendor`** - creates new vendor with Go modules
- ✅ **Build with `-mod=vendor`** - uses vendored dependencies
- ✅ **Commit vendor to git** - if required by your policy

## Migration Steps

If you choose to remove vendor:

```bash
# 1. Remove old vendor directory
git rm -rf vendor/

# 2. Remove old vendor.yml
git rm vendor.yml

# 3. Verify build still works
go build -o bin/invoicer .

# 4. Commit changes
git commit -m "Remove old vendor directory, now using Go modules"
```

## Build Flags Explained

| Flag | Description | Use Case |
|------|-------------|----------|
| (default) | Uses go.mod, respects existing vendor if present | Conflicted state |
| `-mod=mod` | Ignores vendor, always uses go.mod | Current recommendation |
| `-mod=vendor` | Requires vendor directory, ignores go.mod | Air-gapped builds |
| `-mod=readonly` | Uses go.mod but errors if modifications needed | CI/CD pipelines |

## FAQ

**Q: Why does the build fail with "inconsistent vendoring"?**

A: The old vendor directory conflicts with go.mod. Use `go build -mod=mod` or remove the vendor directory.

**Q: Can I use both vendor.yml and go.mod?**

A: No, they're incompatible. Go modules (go.mod) is the modern standard.

**Q: Will removing vendor break anything?**

A: No, Go will download dependencies automatically from go.mod.

**Q: What if I don't have internet access?**

A: Run `go mod vendor` once with internet, then use `-mod=vendor` for builds.

**Q: Is the vendor directory backed up somewhere?**

A: Yes, it's in git history. You can always restore it with `git checkout HEAD -- vendor/`

## Summary

- 🗑️ **Old vendor**: Can be safely removed
- 📦 **Go modules**: Modern standard, preferred
- 🔒 **New vendor** (optional): Run `go mod vendor` if needed
- ✅ **Current setup**: Works with or without vendor directory
