ffi.cdef[[
    bool VirtualProtect(void* lpAddress, unsigned int dwSize, unsigned long  flNewProtect, unsigned long* lpflOldProtect);
    char* VirtualAlloc(void* lpAddress, unsigned int dwSize, uintptr_t flAllocationType, uintptr_t flProtect);
    bool VirtualFree(void* lpAddress, unsigned int dwSize, uintptr_t dwFreeType);

    typedef void(__fastcall* hkUpdateAddonModels)(char*, void*, bool);
    typedef void(__thiscall* oUpdateAddonModels)(char*, bool);
]]

trampoline_hooks =
{
    hooks = {},

    Init = function (self, src, len)
        local trampoline = ffi.C.VirtualAlloc(nil, len + 5, 0x3000, 0x40)
        local stolen_bytes = ffi.new("char[" .. len .. "]")
        ffi.copy(trampoline, src, len)
        ffi.copy(stolen_bytes, src, len)

        local jump_addr = ffi.cast("uintptr_t", src) - ffi.cast("uintptr_t", trampoline) - 5

        ffi.cast("char*", trampoline + len)[0] = 0xE9
        ffi.cast("uintptr_t*", trampoline + len + 1)[0] = jump_addr

        table.insert(self.hooks,
        {
            base = src,
            length = len,
            stolen_bytes = stolen_bytes,
            trampoline = trampoline,

            Hook = function (self, to, hook_cast, original_cast)
                local protect = ffi.new("unsigned long[1]")

                ffi.C.VirtualProtect(self.base, self.length, 0x40, protect)
            
                local jump_addr = ffi.cast("uintptr_t", ffi.cast("void*", ffi.cast(hook_cast, to))) - ffi.cast("uintptr_t", self.base) - 5
                
                ffi.fill(self.base, self.length, 0x90)
                ffi.cast("char*", self.base)[0] = 0xE9
                ffi.cast("uintptr_t*", ffi.cast("uintptr_t", self.base) + 1)[0] = jump_addr
            
                ffi.C.VirtualProtect(self.base, self.length, protect[0], protect)

                return ffi.cast(original_cast, self.trampoline)
            end,

            UnHook = function (self)
                local protect = ffi.new("unsigned long[1]")

                ffi.C.VirtualProtect(self.base, self.length, 0x40, protect)

                ffi.copy(self.base, self.stolen_bytes, self.length)
            
                ffi.C.VirtualProtect(self.base, self.length, protect[0], protect)

                ffi.C.VirtualFree(self.trampoline)
            end
        })

        return self.hooks[#self.hooks]
    end,
}