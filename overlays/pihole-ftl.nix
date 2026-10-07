final: prev: {
  pihole-ftl = prev.pihole-ftl.overrideAttrs (old: {
    env = (old.env or { }) // {
      NIX_CFLAGS_COMPILE = "${old.env.NIX_CFLAGS_COMPILE or ""} -Wno-error=unused-but-set-variable";
    };
  });
}
