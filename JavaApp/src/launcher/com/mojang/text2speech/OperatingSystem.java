package com.mojang.text2speech;

public enum OperatingSystem {
    LINUX("linux"),
    WINDOWS("win"),
    MAC_OS("mac"),
    UNSUPPORTED("none");

    private final String detectWith;

    OperatingSystem(String detectWith) {
        this.detectWith = detectWith;
    }

    public static OperatingSystem get() {
        return UNSUPPORTED;
    }
}
