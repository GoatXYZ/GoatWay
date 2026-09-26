# Manual releases

GoatWay targets WoW Forever (Interface 16001). GitHub Actions are not required.

1. Run `py -3 tests/validate.py` from this repository.
2. Run `py -3 tools/build_release.py`. It creates `dist/GoatWay-1.0.0.zip`.
3. Inspect the ZIP. It must contain one top-level `GoatWay/` folder, including
   `GoatWay.toc`, with no tests, source art tools, local data, or `.git` directory.
4. After the source commit is on GitHub, tag it `v1.0.0` and attach the ZIP to
   a GitHub Release. Use `RELEASE_NOTES.md` as the release description.

For CLI publishing, after confirming distribution rights:

```powershell
git tag v1.0.0
git push origin v1.0.0
gh release create v1.0.0 dist/GoatWay-1.0.0.zip --title "GoatWay 1.0.0" --notes-file RELEASE_NOTES.md --verify-tag
```

Install by extracting the ZIP into `World of Warcraft/_classic_beta_/Interface/AddOns`.
The result should be `AddOns/GoatWay/GoatWay.toc`.
