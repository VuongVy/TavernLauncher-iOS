package net.kdt.patchjna;

import java.io.*;
import java.lang.instrument.ClassFileTransformer;
import java.lang.instrument.IllegalClassFormatException;
import java.lang.instrument.Instrumentation;
import java.security.ProtectionDomain;

public class PatchJNAAgent implements ClassFileTransformer {
    private static final String TARGET_JNA_PLATFORM = "com/sun/jna/Platform";
    private static final String TARGET_MACOSX_FS = "sun/nio/fs/MacOSXFileSystem";

    public byte[] transform(ClassLoader loader, String className, Class<?> classBeingRedefined,
    ProtectionDomain protectionDomain, byte[] classfileBuffer) throws IllegalClassFormatException {
        if (className == null) {
            return classfileBuffer;
        }
        if (className.equals(TARGET_JNA_PLATFORM)) {
            System.out.println("PatchJNAAgent: Replacing class " + className);
            try {
                InputStream inputStream = PatchJNAAgent.class.getClassLoader().getResourceAsStream("com/sun/jna/Platform.class.patch");
                if (inputStream != null) {
                    byte[] replaced = new byte[inputStream.available()];
                    DataInputStream dataInputStream = new DataInputStream(inputStream);
                    dataInputStream.readFully(replaced);
                    return replaced;
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        } else if (className.equals(TARGET_MACOSX_FS)) {
            byte[] patched = patchMacOSXFileSystem(classfileBuffer);
            if (patched != null) {
                System.out.println("PatchJNAAgent: Patched MacOSXFileSystem.isCaseInsensitiveAndPreserving() -> false (iOS APFS sandbox fix)");
                return patched;
            }
        }
        return classfileBuffer;
    }

    /**
     * iOS APFS is case-sensitive and sandboxed: UnixPath.toRealPath(NOFOLLOW_LINKS)
     * calls opendir() on every ancestor directory from "/" when
     * MacOSXFileSystem.isCaseInsensitiveAndPreserving() returns true, which fails
     * with EPERM/AccessDeniedException on /var/mobile/Containers/Data/Application
     * (breaking Cobblemon GraalJS CommonJS root check and any NIO toRealPath call).
     * Flipping isCaseInsensitiveAndPreserving() from iconst_1 (0x04) to iconst_0 (0x03)
     * fixes toRealPath(NOFOLLOW_LINKS) cleanly across all Java 17/21/25 releases.
     */
    public static byte[] patchMacOSXFileSystem(byte[] bytes) {
        try {
            if (bytes == null || bytes.length < 24) return null;
            DataInputStream in = new DataInputStream(new ByteArrayInputStream(bytes));
            int magic = in.readInt();
            if (magic != 0xCAFEBABE) return null;
            in.readUnsignedShort(); // minor
            in.readUnsignedShort(); // major
            int cpCount = in.readUnsignedShort();
            String[] utf8 = new String[cpCount];
            for (int i = 1; i < cpCount; i++) {
                int tag = in.readUnsignedByte();
                switch (tag) {
                    case 1: // Utf8
                        utf8[i] = in.readUTF();
                        break;
                    case 3: // Integer
                    case 4: // Float
                    case 9: // Fieldref
                    case 10: // Methodref
                    case 11: // InterfaceMethodref
                    case 12: // NameAndType
                    case 17: // Dynamic
                    case 18: // InvokeDynamic
                        in.skipBytes(4);
                        break;
                    case 5: // Long
                    case 6: // Double
                        in.skipBytes(8);
                        i++; // 2 constant pool slots
                        break;
                    case 7: // Class
                    case 8: // String
                    case 16: // MethodType
                    case 19: // Module
                    case 20: // Package
                        in.skipBytes(2);
                        break;
                    case 15: // MethodHandle
                        in.skipBytes(3);
                        break;
                    default:
                        return null;
                }
            }
            in.skipBytes(6); // access_flags, this_class, super_class
            int ifCount = in.readUnsignedShort();
            in.skipBytes(ifCount * 2);
            int fieldCount = in.readUnsignedShort();
            for (int i = 0; i < fieldCount; i++) {
                in.skipBytes(6);
                int attrCount = in.readUnsignedShort();
                for (int a = 0; a < attrCount; a++) {
                    in.skipBytes(2);
                    int len = in.readInt();
                    in.skipBytes(len);
                }
            }
            int methodCount = in.readUnsignedShort();
            for (int i = 0; i < methodCount; i++) {
                in.skipBytes(2); // access_flags
                int nameIdx = in.readUnsignedShort();
                int descIdx = in.readUnsignedShort();
                boolean isTarget = "isCaseInsensitiveAndPreserving".equals(utf8[nameIdx])
                        && "()Z".equals(utf8[descIdx]);
                int attrCount = in.readUnsignedShort();
                for (int a = 0; a < attrCount; a++) {
                    int attrNameIdx = in.readUnsignedShort();
                    int attrLen = in.readInt();
                    if (isTarget && "Code".equals(utf8[attrNameIdx])) {
                        in.skipBytes(4); // max_stack, max_locals
                        int codeLen = in.readInt();
                        int codeStartOffset = bytes.length - in.available();
                        if (codeLen == 2
                                && bytes[codeStartOffset] == 0x04 // iconst_1
                                && bytes[codeStartOffset + 1] == (byte) 0xAC) { // ireturn
                            byte[] copy = bytes.clone();
                            copy[codeStartOffset] = 0x03; // iconst_0
                            return copy;
                        }
                        return null;
                    } else {
                        in.skipBytes(attrLen);
                    }
                }
            }
        } catch (Throwable t) {
            t.printStackTrace();
        }
        return null;
    }

    public static void premain(String args, Instrumentation instrumentation) {
        System.out.println("PatchJNAAgent: premain called");
        PatchJNAAgent agent = new PatchJNAAgent();
        instrumentation.addTransformer(agent, true);
        try {
            Class<?> macFs = Class.forName("sun.nio.fs.MacOSXFileSystem");
            if (instrumentation.isRetransformClassesSupported() && instrumentation.isModifiableClass(macFs)) {
                instrumentation.retransformClasses(macFs);
            }
        } catch (ClassNotFoundException ignored) {
            // Non-macOS/iOS JVM
        } catch (Throwable t) {
            System.out.println("PatchJNAAgent: retransform MacOSXFileSystem skipped: " + t);
        }
    }
}
