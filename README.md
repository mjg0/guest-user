# Guest User

This repository contains the information necessary to set up a Linux guest user with a couple of convenient features:

- its home directory is a tmpfs, and is cleared on each logout
- only one instance can be logged in at a time
- login can be restricted to one or a few services

Unfortunately PAM is fragile and doesn't lend itself to automation of whole the install process, so you'll have to carefully follow the instructions below.



## Non-PAM Setup

You can run `make install` to set up everything that can reasonably be automated: the creation of the guest user and installation of the tmpfs setup script. There are a few variables you can supply to `make` to customize your setup:

- `GUEST_USER`: the username of the guest user, default `guest-user`
- `GUEST_HOME`: the home directory of the guest user, default `/home/guest-user`
- `GUEST_HOME_SIZE`: the size of the tmpfs that will be mounted at `$GUEST_HOME`, default `1024M`.

The guest user account is created interactively, so you'll be asked to set a password.

You can of course run these two steps manually--just create a guest user, change the variables at the top of `guest-user-home-setup.sh` as appropriate, and copy `guest-user-home-setup.sh` into `/usr/local/libexec/`. The `Makefile` sets the guest user's shell to `/sbin/nologin`, which is probably best for most use cases.

If you want custom files in your guest user's home directory, put them in `/etc/guest-user/skel`. This will be copied in after `/etc/skel` when the home tmpfs is set up.



## PAM Setup

This will vary based on your system, but the basic idea is this: you want to deny the guest user access by most means, and where it is allowed to log in, you want to force it to run `guest-user-home-setup.sh`. What follows is an example of how that might look.

### Create an `authselect` profile

You probably want to use `authselect` if you have it. Here's how I created a profile:

```
authselect create-profile guest-user -b local --symlink-pam --symlink-meta
rm /etc/authselect/custom/guest-user/system-auth
cp /usr/share/authselect/default/local/system-auth /etc/authselect/custom/guest-user/system-auth
```

The `symlink-*` flags tell it to fall back to the default profile for files you don't replace, so your system will still get updates for everything but `system-auth`.

### Update `system-auth`

I put these two lines near the bottom of `/etc/authselect/custom/guest-user/system-auth`, right above the last `pam_unix.so` line:

```
account     [success=1 default=ignore]                   pam_succeed_if.so quiet user != guest-user
account     required                                     pam_succeed_if.so quiet service in sddm:gdm-password
```

This means that if the user is `guest-user`, authentication will fail unless the service is `sddm` (the display manager I use); this means that the guest user is only able to log in via the "normal" graphical way. You might want `gdm-password`, or `lightdm`, or multiple (colon-separated, e.g. `sddm:lightdm`), depending on how you want to enable login.

### Add `guest-user-home`

Copy `guest-user-home` into `/etc/pam.d/` to enable PAM to call `guest-user-home-setup.sh`.

### Update other services

For each of the services you list in `system-auth`, you'll need to update that service to use `guest-user-home-setup.sh`. Since Fedora 43's `authselect` doesn't manage `sddm`, I had to edit `/etc/pam.d/sddm` directly. Just two lines are needed:

```
account     include       guest-user-home
```

...goes right *after* `account include password-auth`, and:

```
session     include       guest-user-home
```

...goes right *before* `session include password-auth`.

### Apply changes

`authselect select custom/guest-user` will apply your changes. This done, your guest user account should work



## Improvements

If you got this working on a different system I would love an issue or pull request documenting your process!