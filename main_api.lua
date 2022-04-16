function array_walk_recursive(array, callback)
    for k, v in pairs(array) do
        if(type(v) == "table") then
            array_walk_recursive(v, callback)
        else
            callback(k, v)
        end
    end
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
-- getprop
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