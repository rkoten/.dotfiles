# Source - https://stackoverflow.com/a/66049504
# Posted by David Bailey
# Retrieved 2026-05-29, License - CC BY-SA 4.0

cargo install --locked $(cargo install --list | egrep '^[a-z0-9_-]+ v[0-9.]+:$' | cut -f1 -d' ')
