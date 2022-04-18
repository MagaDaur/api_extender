ffi.cdef[[
	typedef struct{
		void*   fnHandle;
		char    szName[260];
		__int32 nLoadFlags;
		__int32 nServerCount;
		__int32 type;
		__int32 flags;
		float  vecMins[3];
		float  vecMaxs[3];
		float   radius;
		char    pad[0x1C];
	}model_t;

    typedef struct
	{
			char padBase[4];
			char* consoleName;
			char pad0[12];
			int iMaxClip1;
			int iMaxClip2;
			int iDefaultClip1;
			int iDefaultClip2;
			int iPrimaryMaxReserveAmmo;
			int iSecondaryMaxReserveAmmo;
			const char* szWorldModel;
			const char* szViewModel;
			const char* szDroppedModel;
			char pad1[0x50];
			const char* szHudName;
			const char* szWeaponName;
	}WeaponInfo_t;

    typedef model_t*(__thiscall* GetModel_t)(void*);

    void* CreateFileA(
        const char*                lpFileName,
        unsigned long                 dwDesiredAccess,
        unsigned long                 dwShareMode,
        unsigned long lpSecurityAttributes,
        unsigned long                 dwCreationDisposition,
        unsigned long                 dwFlagsAndAttributes,
        void*                hTemplateFile
    );

    bool ReadFile(
        void*       hFile,
        char*       lpBuffer,
        unsigned long        nNumberOfBytesToRead,
        unsigned long*      lpNumberOfBytesRead,
        int lpOverlapped
    );
    bool WriteFile(
        void*       hFile,
        char*      lpBuffer,
        unsigned long        nNumberOfBytesToWrite,
        unsigned long*      lpNumberOfBytesWritten,
        void* lpOverlapped
    );
    unsigned long GetFileSize(
        void*  hFile,
        unsigned long* lpFileSizeHigh
    );

    bool CloseHandle(
        void * hHandle
    );

    typedef struct _OVERLAPPED {
        unsigned long* Internal;
        unsigned long* InternalHigh;
        union {
            struct {
            unsigned long Offset;
            unsigned long OffsetHigh;
            } DUMMYSTRUCTNAME;
            void* Pointer;
        } DUMMYUNIONNAME;
        void*    hEvent;
    } OVERLAPPED, *LPOVERLAPPED;

    int CreateDirectoryA(const char* lpPathName, void* lpSecurityAttributes);

    void* GetClipboardData(unsigned int uFormat);
    void* GlobalLock(void* hMem);
    int GlobalUnlock(void* hMem);
    int OpenClipboard(void* hWndNewOwner);
    int CloseClipboard();
    void* GetActiveWindow();
]]

local g_EntityList = Utils.CreateInterface("client.dll", "VClientEntityList003")
local EntityListVTable = ffi.cast("uintptr_t**", g_EntityList)[0]
local GetClientEntity = ffi.cast("void*(__thiscall*)(void*, int)", EntityListVTable[3])

g_WeaponSystem = ffi.cast("void**", ffi.cast("uintptr_t", Utils.PatternScan("client.dll", "8B 35 ? ? ? ? FF 10 0F B7 C0")) + 0x2)[0]
local WeaponSystemVTable = ffi.cast("uintptr_t**", g_WeaponSystem)[0]
GetWeaponInfo = ffi.cast("WeaponInfo_t*(__thiscall*)(void*, int)", WeaponSystemVTable[2])

C_BaseEntity.Ptr = function (self) -- remove after alpha update
    return GetClientEntity(g_EntityList, self:EntIndex())
end

C_BaseEntity.GetRenderable = function (self)
	return ffi.cast("void*", ffi.cast("uintptr_t", self:Ptr()) + 0x4)
end

C_BaseEntity.IsLocalPlayer = function (self)
	return self:EntIndex() == EngineClient.GetLocalPlayer()
end

C_BaseEntity.GetModelName = function (self)
	local renderable = ffi.cast("uintptr_t**", self:GetRenderable())
	local renderable_vtable = renderable[0]
	local GetModel = ffi.cast("GetModel_t", renderable_vtable[8])

	return ffi.string(GetModel(renderable).szName)
end

function C_BasePlayer:GetWeapons()
    local plyWeapons = self:GetProp("m_hMyWeapons");
    local returnTable = {};

    if (type(plyWeapons) == "table" and #plyWeapons > 0) then 
        for i = 1, #plyWeapons do
            local wep = EntityList.GetWeaponFromHandle(plyWeapons[i]);
            if (wep ~= nil) then
                table.insert(returnTable, wep);
            end
        end
    end

    return returnTable;
end
-- Check flags
function C_BasePlayer:IsOnGround()
    return bit.band(self:GetProp("m_fFlags"), bit.lshift(1,0)) ~= 0
end

function C_BasePlayer:IsInAir()
    return bit.band(self:GetProp("m_fFlags"), bit.lshift(1,0)) == 0
end

function C_BasePlayer:IsDucking()
    return bit.band(self:GetProp("m_fFlags"), bit.lshift(1,1)) ~= 0
end

function C_BasePlayer:IsWaterJump()
    return bit.band(self:GetProp("m_fFlags"), bit.lshift(1,3)) ~= 0
end

function C_BasePlayer:IsOnTrain()
    return bit.band(self:GetProp("m_fFlags"), bit.lshift(1,4)) ~= 0
end

function C_BasePlayer:IsInRain()
    return bit.band(self:GetProp("m_fFlags"), bit.lshift(1,5)) ~= 0
end

function C_BasePlayer:IsFrozen()
    return bit.band(self:GetProp("m_fFlags"), bit.lshift(1,6)) ~= 0
end

function C_BasePlayer:IsAtControls()
    return bit.band(self:GetProp("m_fFlags"), bit.lshift(1,7)) ~= 0
end

function C_BasePlayer:IsClient()
    return bit.band(self:GetProp("m_fFlags"), bit.lshift(1,8)) ~= 0
end

function C_BasePlayer:IsFakeClient()
    return bit.band(self:GetProp("m_fFlags"), bit.lshift(1,9)) ~= 0
end

function C_BasePlayer:IsInWater()
    return bit.band(self:GetProp("m_fFlags"), bit.lshift(1,10)) ~= 0
end

function C_BasePlayer:GetVelocity()
    return self:GetProp("m_vecVelocity")
end

function C_BasePlayer:IsAlive()
    return self:GetProp("m_iHealth") > 0
end

function C_BasePlayer:GetHP()
    return self:GetProp("m_iHealth")
end

vmthooks = {}
function CreateVMT(target)
    target = ffi.cast("uintptr_t**", target) -- cast void* to uintptr_t** to get virtual table

    local pOriginalTable = target[0] -- get virtual table base
    local iVMTSize = 0 -- init virtual table size variable

    while(pOriginalTable[iVMTSize] ~= 0x0) do
        iVMTSize = iVMTSize + 1 -- increase until we hit NULL to find virtual table size
    end

    local pNewVTable = ffi.new("uintptr_t[".. iVMTSize .."]") -- allocate memory for the replacement of original virtual table
    ffi.copy(pNewVTable, pOriginalTable, iVMTSize * ffi.sizeof("uintptr_t")) -- copy original virtual table's methods addresses to our virtual table

    target[0] = pNewVTable -- overriding vtable base address

    table.insert(vmthooks, {base = target, original = pOriginalTable, size = iVMTSize, new = pNewVTable}) -- save some variables for further usage

    return vmthooks[#vmthooks] --
end

function DeleteVMT(vmt)
    vmt.base[0] = vmt.original -- restore original vtable base address
end

function GetOriginal(vmt, idx, cast)
    return ffi.cast(cast, vmt.original[idx]) -- get original method address
end

function Hook(vmt, idx, to, cast)
    vmt.new[idx] = ffi.cast("uintptr_t", ffi.cast(cast, to)) -- override method address
end

function UnHook(vmt, idx)
    vmt.new[idx] = vmt.original[idx] -- resotre method address
end

function RemoveHooks()
    for _, vmt in pairs(vmthooks) do
        DeleteVMT(vmt) -- restore all vmt hooks that we have created
    end
end

array_walk_recursive = function(array, callback)
    for k, v in pairs(array) do
        if(type(v) == "table") then
            array_walk_recursive(v, callback)
        else
            callback(k, v)
        end
    end
end

function write_file(path, data)
    local pfile = ffi.cast("void*", ffi.C.CreateFileA(path, 0xC0000000, 0x00000004, 0, 0x2, 0x80, nil))

    ffi.C.WriteFile(pfile, ffi.cast("char*", data), string.len(data), nil, nil)

    ffi.C.CloseHandle(pfile)
end

function read_file(path)
    local pfile = ffi.C.CreateFileA(path, 0xC0000000, 0x00000004, 0, 0x4, 0x80, nil)

    local size = ffi.C.GetFileSize(pfile, nil)
    local buff = ffi.new("char[" .. (size + 1) .. "]")
    ffi.C.ReadFile(pfile, buff, size, nil, 0)
    ffi.C.CloseHandle(pfile)

    return ffi.string(buff)
end

function GetClipBoardText()
    local result

    local window = ffi.C.GetActiveWindow()

    ffi.C.OpenClipboard(window)

    local data = ffi.C.GetClipboardData(1)

    ffi.C.GlobalLock(data)

    result = ffi.string(data)

    ffi.C.GlobalUnlock(data)

    ffi.C.CloseClipboard()

    return result
end