-- Dance4 = maos nas pernas; Dance5 = pernas abertas e maos apoiadas no chao.
-- Dance4: torso horizontal e cabeca para a frente. Dance5: corpo inclinado, pernas abertas e quadril em movimento.
-- Dance5 e a variacao guardada nesta conversa, nao um arquivo externo.
-- Potassium / LocalPlayer.Character, R15, so visual local. Sem IDs ou remotes.
-- Studio: use como LocalScript em StarterPlayerScripts e teste no modo Play.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = assert(Players.LocalPlayer, "Execute no cliente, dentro do jogo")
local playerGui = player:WaitForChild("PlayerGui")
-- A função de encerramento dentro da GUI funciona até entre execuções que
-- recebam ambientes globais diferentes no executor.
local GUI_NAME = "Dance45LocalMenu"
for _, oldName in ipairs({"Dance4PotassiumLocalMenu", GUI_NAME}) do
    local previous = playerGui:FindFirstChild(oldName)
    if previous then
        local shutdown = previous:FindFirstChild("Shutdown")
        if shutdown and shutdown:IsA("BindableFunction")
            and shutdown:GetAttribute("Ready") then
            pcall(function() shutdown:Invoke() end)
        end
        if previous.Parent then previous:Destroy() end
    end
end
local BASE = {
    PulseSeconds = 0.42, SamplesPerPulse = 40,
    PelvisLeanDegrees = 98, PelvisPitchDegrees = 6.0,
    HipBackRatio = 0.015, HipForeAftRatio = 0.045,
    LegBackRatio = 0.04, FootSpreadRatio = 0.07, ToeOutDegrees = 0,
}
local CONFIGS = {
    Dance4 = {
        TorsoLeanDegrees = 90,
        HeadDownDegrees = 0,
        HeadSwayDegrees = 0,
        HandMode = "Leg",
        -- Cada impulso dobra e estende os joelhos. A média permanece próxima
        -- da postura original, com o pé fixo e o torso apontando para a frente.
        LegPulseReach = 0.009,
        LegPulseMeanReach = 0.986,
        -- pernas bem mais abertas para criar um vao maior no meio
        FootSpreadRatio = 0.30,
        ToeOutDegrees = 5,
    },
    Dance5 = {
        -- Vista por tras: pernas em V e maos apoiadas no chao a frente.
        TorsoLeanDegrees = 92.4, -- mais 5% abaixo da inclinacao anterior
        HeadDownDegrees = 0, -- rosto olha para a frente; pescoco continua preso ao torso
        HeadSwayDegrees = 0.15,
        HandMode = "Ground",
        PulseSeconds = 0.42,
        SamplesPerPulse = 48,
        PelvisLeanDegrees = 75,
        PelvisPitchDegrees = 9.0,
        HipBackRatio = 0.03,
        HipForeAftRatio = 0.025,
        HipVerticalRatio = 0.005,
        -- Apoio baixo, mas com as pernas formando um V bem visivel.
        LegReachRatio = 0.82, -- quadril mais baixo para as palmas alcancarem o chao
        LegPulseRatio = 0.045, -- joelhos flexionam/estendem em cada impulso
        -- Pernas bem abertas como na referencia.
        LegBackRatio = 0.13,
        FootSpreadRatio = 0.50,
        ToeOutDegrees = 13,
        -- Distancia lateral das palmas na parede.
        ArmSpreadRatio = 0.13,
    },
}
for _, cfg in pairs(CONFIGS) do
    for key, value in pairs(BASE) do
        if cfg[key] == nil then
            cfg[key] = value
        end
    end
end
local ORDER = {
    "LowerTorso", "UpperTorso", "Head",
    "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
    "RightUpperLeg", "RightLowerLeg", "RightFoot",
    "LeftUpperArm", "LeftLowerArm", "LeftHand",
    "RightUpperArm", "RightLowerArm", "RightHand",
}
local PARENT = {
    LowerTorso = "HumanoidRootPart", UpperTorso = "LowerTorso", Head = "UpperTorso",
    LeftUpperLeg = "LowerTorso", LeftLowerLeg = "LeftUpperLeg", LeftFoot = "LeftLowerLeg",
    RightUpperLeg = "LowerTorso", RightLowerLeg = "RightUpperLeg", RightFoot = "RightLowerLeg",
    LeftUpperArm = "UpperTorso", LeftLowerArm = "LeftUpperArm", LeftHand = "LeftLowerArm",
    RightUpperArm = "UpperTorso", RightLowerArm = "RightUpperArm", RightHand = "RightLowerArm",
}
local LEG_NAMES = {
    "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
    "RightUpperLeg", "RightLowerLeg", "RightFoot",
}
local V = Vector3.new
local FORWARD = V(0, 0, -1)
local SIDES = {"Left", "Right"}
local function rx(degrees)
    return CFrame.Angles(math.rad(degrees), 0, 0)
end
local function bindWorld(data)
    local world = {HumanoidRootPart = CFrame.new()}
    for _, name in ipairs(ORDER) do
        local joint = data[name]
        world[name] = world[PARENT[name]] * joint.c0 * joint.c1:Inverse()
    end
    return world
end
local function anchoredAt(position, rotation, childAttachment)
    return CFrame.new(position) * rotation * CFrame.new(-childAttachment.Position)
end
local function basis(up, forward)
    up = up.Unit
    local right = forward:Cross(up).Unit
    return CFrame.fromMatrix(V(0, 0, 0), right, up, right:Cross(up))
end
local function segmentRotation(nativeVector, worldVector, pole)
    return basis(-worldVector.Unit, pole) * basis(-nativeVector.Unit, FORWARD):Inverse()
end
local function solveLeg(data, world, side, footCF)
    local upper, lower, foot = side.."UpperLeg", side.."LowerLeg", side.."Foot"
    local hip, knee, ankle = data[upper], data[lower], data[foot]
    local nativeUpper = knee.c0.Position - hip.c1.Position
    local nativeLower = ankle.c0.Position - knee.c1.Position
    local l1, l2 = nativeUpper.Magnitude, nativeLower.Magnitude
    local h = (world.LowerTorso * hip.c0).Position
    local a = (footCF * ankle.c1).Position
    local delta = a - h
    local d = delta.Magnitude
    assert(d > math.abs(l1 - l2) + 0.0001 and d < l1 + l2 - 0.0001,
        "Pe fora do alcance")
    local direction = delta.Unit
    local sign = side == "Left" and -1 or 1
    local pole = V(sign * 0.10, 0, -1)
    local bend = (pole - direction * pole:Dot(direction)).Unit
    local along = (l1*l1 - l2*l2 + d*d) / (2*d)
    local away = math.sqrt(math.max(0, l1*l1 - along*along))
    local k = h + direction*along + bend*away
    world[upper] = anchoredAt(h, segmentRotation(nativeUpper, k-h, bend), hip.c1)
    world[lower] = anchoredAt(k, segmentRotation(nativeLower, a-k, bend), knee.c1)
    world[foot] = footCF
end
local function solveArmOnLeg(data, world, side)
    -- Apoia as mãos perto dos joelhos e um pouco para dentro.
    -- O alvo acompanha a perna sem exigir muita flexão do cotovelo.
    local upperArm, lowerArm, hand = side.."UpperArm", side.."LowerArm", side.."Hand"
    local shoulder, elbow, wrist = data[upperArm], data[lowerArm], data[hand]
    local h = (world.UpperTorso * shoulder.c0).Position
    local sign = side == "Left" and -1 or 1
    local nativeUpper = elbow.c0.Position - shoulder.c1.Position
    local nativeLower = wrist.c0.Position - elbow.c1.Position
    local l1, l2 = nativeUpper.Magnitude, nativeLower.Magnitude
    local reach = l1+l2
    local hip = (world.LowerTorso*data[side.."UpperLeg"].c0).Position
    local knee = (world[side.."UpperLeg"]*data[side.."LowerLeg"].c0).Position
    local ankle = (world[side.."LowerLeg"]*data[side.."Foot"].c0).Position
    local inset = V(-sign*reach*0.055, 0, -reach*0.045)
    local target = knee + V(0, reach*0.09, 0) + inset
    local distance = (target-h).Magnitude
    if distance < reach*0.94 then
        -- Se o braço ficaria dobrado, desliza a mão suavemente rumo à canela.
        local lowerTarget = knee:Lerp(ankle,0.48) + inset
        local lo, hi = 0, 1
        for _ = 1, 12 do
            local mid = (lo+hi)*0.5
            if (target:Lerp(lowerTarget,mid)-h).Magnitude < reach*0.94 then
                lo = mid
            else
                hi = mid
            end
        end
        target = target:Lerp(lowerTarget,hi)
    elseif distance > reach*0.985 then
        -- Em avatares menores, traz o apoio um pouco acima do joelho.
        local upperTarget = hip:Lerp(knee,0.62) + inset
        local lo, hi = 0, 1
        for _ = 1, 12 do
            local mid = (lo+hi)*0.5
            if (target:Lerp(upperTarget,mid)-h).Magnitude > reach*0.985 then
                lo = mid
            else
                hi = mid
            end
        end
        target = target:Lerp(upperTarget,hi)
    end
    local delta = target-h
    local d = delta.Magnitude
    if d > reach*0.998 then
        target = h + delta.Unit*(reach*0.998)
        delta, d = target-h, reach*0.998
    end
    assert(d > math.abs(l1-l2)+0.001, "Mão muito próxima do ombro")
    local direction = delta.Unit
    local pole = V(sign*0.6, -0.25, -0.4) -- cotovelos abrem pouco para fora
    local bend = (pole-direction*pole:Dot(direction)).Unit
    local along = (l1*l1-l2*l2+d*d)/(2*d)
    local away = math.sqrt(math.max(0,l1*l1-along*along))
    local k = h + direction*along + bend*away
    local ru = segmentRotation(nativeUpper, k-h, bend)
    local rl = segmentRotation(nativeLower, target-k, bend)
    world[upperArm] = anchoredAt(h, ru, shoulder.c1)
    world[lowerArm] = anchoredAt(k, rl, elbow.c1)
    -- Punho neutro: a mão aponta na continuação do antebraço.
    world[hand] = world[lowerArm] * wrist.c0 * wrist.c1:Inverse()
end
local function solveArmWall(data, world, side, baseTorso, wallZ, cfg)
    local upperArm, lowerArm, hand = side.."UpperArm", side.."LowerArm", side.."Hand"
    local shoulder, elbow, wrist = data[upperArm], data[lowerArm], data[hand]
    local h = (world.UpperTorso * shoulder.c0).Position
    local base = (baseTorso * shoulder.c0).Position
    local sign = side == "Left" and -1 or 1
    local nativeUpper = elbow.c0.Position - shoulder.c1.Position
    local nativeLower = wrist.c0.Position - elbow.c1.Position
    local l1, l2 = nativeUpper.Magnitude, nativeLower.Magnitude
    local reach = l1+l2
    -- Alvo parado no plano da parede; sem parede por perto, mostra o gesto
    -- de apoio no mesmo ponto relativo ao torso ate o jogador se aproximar.
    local target = V(base.X + sign*reach*cfg.ArmSpreadRatio,
        base.Y - reach*0.12,
        wallZ or (base.Z - reach*0.93))
    local delta = target - h
    local d = delta.Magnitude
    -- Estende quase todo o braço. Se o avatar estiver colado na parede,
    -- a palma prioriza a linha do braço; afaste-se um pouco para encosta-la.
    if d < 0.0001 then delta = V(sign*0.08,-0.12,-1) end
    delta = delta.Unit*(reach*0.995)
    target, d = h+delta, reach*0.995
    local direction = delta.Unit
    local pole = V(sign*0.7,-0.6,0.1)
    local bend = (pole-direction*pole:Dot(direction)).Unit
    local along = (l1*l1-l2*l2+d*d)/(2*d)
    local away = math.sqrt(math.max(0,l1*l1-along*along))
    local k = h+direction*along+bend*away
    world[upperArm] = anchoredAt(h,segmentRotation(nativeUpper,k-h,bend),shoulder.c1)
    world[lowerArm] = anchoredAt(k,segmentRotation(nativeLower,target-k,bend),elbow.c1)
    -- Deixa a palma voltada para o plano da parede.
    world[hand] = anchoredAt(target,CFrame.new(),wrist.c1)
end
local function solveArmGround(data, world, side, groundY, baseTorso, character, cfg)
    -- Mãos perto do piso e alvos estáveis: parecem sustentar o peito.
    -- Caso a proporção do avatar não alcance o piso, estica sem deslocar a junta.
    local upperArm, lowerArm, hand = side.."UpperArm", side.."LowerArm", side.."Hand"
    local shoulder, elbow, wrist = data[upperArm], data[lowerArm], data[hand]
    local h = (world.UpperTorso * shoulder.c0).Position
    local sign = side == "Left" and -1 or 1
    local nativeUpper = elbow.c0.Position - shoulder.c1.Position
    local nativeLower = wrist.c0.Position - elbow.c1.Position
    local l1, l2 = nativeUpper.Magnitude, nativeLower.Magnitude
    local reach = l1+l2
    local baseShoulder = (baseTorso * shoulder.c0).Position
    local handPart = character:FindFirstChild(hand)
    local wristY = groundY + (handPart and handPart.Size.Y or 0.3)*0.5
        + wrist.c1.Position.Y
    local sideways = sign*reach*(cfg.ArmSpreadRatio or 0.09)
    local drop = h.Y-wristY
    -- Avança a mão até o ponto em que o braço fica quase no seu comprimento
    -- total. Assim não dobra o cotovelo para alcançar um alvo próximo demais.
    local forward = math.sqrt(math.max(0, (reach*0.995)^2-drop^2-sideways^2))
    local target = V(h.X+sideways, wristY, h.Z-forward)
    local delta = target-h
    local d = delta.Magnitude
    if d > reach*0.998 then
        target = h + delta.Unit*(reach*0.998)
        delta, d = target-h, reach*0.998
    end
    assert(d > math.abs(l1-l2)+0.001, "Mão muito próxima do ombro")
    local direction = delta.Unit
    local pole = V(sign*0.6, -0.25, -0.4) -- cotovelos abrem pouco para fora
    local bend = (pole-direction*pole:Dot(direction)).Unit
    local along = (l1*l1-l2*l2+d*d)/(2*d)
    local away = math.sqrt(math.max(0,l1*l1-along*along))
    local k = h + direction*along + bend*away
    local ru = segmentRotation(nativeUpper, k-h, bend)
    local rl = segmentRotation(nativeLower, target-k, bend)
    world[upperArm] = anchoredAt(h, ru, shoulder.c1)
    world[lowerArm] = anchoredAt(k, rl, elbow.c1)
    -- Punho neutro: a mão aponta na continuação do antebraço.
    -- Palma horizontal voltada para baixo, sem torcer o punho.
    world[hand] = anchoredAt(target,CFrame.new(),wrist.c1)
end
local function bake(data, cfg, character)
    assert(cfg.PulseSeconds > 0 and cfg.SamplesPerPulse >= 12, "Cadência/amostragem inválida")
    local bind = bindWorld(data)
    local nativeHipMid = (data.LeftUpperLeg.c0.Position + data.RightUpperLeg.c0.Position)*0.5
    local restHipMid = bind.LowerTorso:PointToWorldSpace(nativeHipMid)
    local lengths, feet = {}, {}
    for _, side in ipairs({"Left", "Right"}) do
        local hip, knee, ankle = data[side.."UpperLeg"], data[side.."LowerLeg"], data[side.."Foot"]
        lengths[side] = (knee.c0.Position-hip.c1.Position).Magnitude
            + (ankle.c0.Position-knee.c1.Position).Magnitude
        local sign = side == "Left" and -1 or 1
        local rest = bind[side.."Foot"]
        local neutralPelvis = rx(-cfg.PelvisLeanDegrees)
        local neutralHip = restHipMid
            + neutralPelvis:VectorToWorldSpace(hip.c0.Position-nativeHipMid)
            + V(0, 0, lengths[side]*cfg.HipBackRatio)
        -- O tornozelo fica abaixo do quadril na postura inclinada, evitando
        -- a perna projetada para a frente que aparecia na prévia anterior.
        local ankleOffset = (CFrame.new()*ankle.c1).Position
        feet[side] = CFrame.new(
            neutralHip.X + sign*lengths[side]*cfg.FootSpreadRatio - ankleOffset.X,
            rest.Position.Y,
            neutralHip.Z + lengths[side]*cfg.LegBackRatio - ankleOffset.Z)
            * CFrame.Angles(0, math.rad(-sign*cfg.ToeOutDegrees), 0)
    end
    local legLength = (lengths.Left+lengths.Right)*0.5
    local groundY = math.min(
        feet.Left.Position.Y-character.LeftFoot.Size.Y*0.5,
        feet.Right.Position.Y-character.RightFoot.Size.Y*0.5)
    local duration = cfg.PulseSeconds*2 -- dois impulsos, leve alternância de intensidade
    local count = cfg.SamplesPerPulse*2
    local frames = {}
    local fixedTorso, fixedHead, wallZ
    for sample = 0, count-1 do
        local t = sample/count*duration
        local p = 2*math.pi*t/cfg.PulseSeconds
        local amount = 1 + 0.03*math.cos(p*0.5)
        local pulse = (math.cos(p) + 0.12*math.sin(2*p))*amount
        local pelvisR = rx(-cfg.PelvisLeanDegrees + cfg.PelvisPitchDegrees*pulse)
        local phase = math.sin(p-0.8) + 0.08*math.sin(2*p-1.6)
        local hipZ = restHipMid.Z + legLength*cfg.HipBackRatio
            + legLength*cfg.HipForeAftRatio*phase
        -- Cada danca escolhe o alcance da perna sem deslocar os pes.
        local hipY = math.huge
        for _, side in ipairs({"Left", "Right"}) do
            local hip = data[side.."UpperLeg"]
            local ankle = data[side.."Foot"]
            local offset = pelvisR:VectorToWorldSpace(hip.c0.Position-nativeHipMid)
            local a = (feet[side]*ankle.c1).Position
            local dx, dz = restHipMid.X+offset.X-a.X, hipZ+offset.Z-a.Z
            local reachRatio = cfg.LegReachRatio or 0.996
            if cfg.HandMode == "Leg" then
                -- O alcance menor flexiona os joelhos, e o maior os estende.
                -- Usa a mesma fase do quadril, sem descolar os pés do chão.
                reachRatio = cfg.LegPulseMeanReach - cfg.LegPulseReach*pulse
            elseif cfg.HandMode == "Wall" or cfg.HandMode == "Ground" then
                -- A pelve desce no impulso e sobe na recuperação;
                -- as mãos ficam no mesmo plano da parede.
                reachRatio = cfg.LegReachRatio - cfg.LegPulseRatio*pulse
            end
            local reach = lengths[side]*reachRatio
            local horizontal2 = dx*dx + dz*dz
            local height = math.sqrt(math.max(0.0001, reach*reach-horizontal2))
            hipY = math.min(hipY, a.Y+height-offset.Y)
        end
        -- Na Dance5, o quadril sobe e desce um pouco junto com a pelve.
        if cfg.HipVerticalRatio then
            hipY = hipY + legLength*cfg.HipVerticalRatio*pulse
        end
        local hipMid = V(restHipMid.X, hipY, hipZ)
        local world = {HumanoidRootPart = CFrame.new()}
        world.LowerTorso = CFrame.new(hipMid)*pelvisR*CFrame.new(-nativeHipMid)
        if not fixedTorso then
            fixedTorso = anchoredAt(
                (world.LowerTorso*data.UpperTorso.c0).Position,
                rx(-cfg.TorsoLeanDegrees), data.UpperTorso.c1)
            fixedHead = anchoredAt(
                (fixedTorso*data.Head.c0).Position,
                rx(-cfg.HeadDownDegrees), data.Head.c1)
            if cfg.HandMode == "Wall" then
                local root = character:FindFirstChild("HumanoidRootPart")
                if root then
                    local params = RaycastParams.new()
                    params.FilterType = Enum.RaycastFilterType.Exclude
                    params.FilterDescendantsInstances = {character}
                    local origin = root.CFrame:PointToWorldSpace(fixedTorso.Position)
                    local cast = workspace:Raycast(origin,root.CFrame.LookVector*legLength*1.4,params)
                    if cast and math.abs(cast.Normal.Y) < 0.3
                        and cast.Normal:Dot(root.CFrame.LookVector) < -0.7 then
                        local handPart = character:FindFirstChild("LeftHand")
                        local handDepth = handPart and handPart.Size.Z or 0.6
                        wallZ = root.CFrame:PointToObjectSpace(cast.Position).Z
                            + handDepth*0.5 + 0.02
                    end
                end
            end
            if cfg.HandMode == "Ground" then
            -- Abaixa o ombro apenas para a variacao de apoio no chao.
            local torsoDrop = 0
            for _, side in ipairs({"Left", "Right"}) do
                local shoulder = data[side.."UpperArm"]
                local elbow = data[side.."LowerArm"]
                local wrist = data[side.."Hand"]
                local reach = (elbow.c0.Position-shoulder.c1.Position).Magnitude
                    + (wrist.c0.Position-elbow.c1.Position).Magnitude
                local handPart = character:FindFirstChild(side.."Hand")
                local wristY = groundY+(handPart and handPart.Size.Y or 0.3)*0.5
                    + wrist.c1.Position.Y
                local shoulderY = (fixedTorso*shoulder.c0).Position.Y
                torsoDrop = math.max(torsoDrop, shoulderY-wristY-reach*0.94)
            end
            if torsoDrop > 0 then
                local shift = CFrame.new(0,-torsoDrop,0)
                fixedTorso = shift*fixedTorso
                fixedHead = shift*fixedHead
            end
            end
        end
        -- O peito acompanha a pelve em uma fração do deslocamento.
        -- A cabeça acompanha ainda menos; os braços respondem aos ombros.
        world.UpperTorso = CFrame.new(0, legLength*0.003*pulse, legLength*0.008*phase)
            * fixedTorso * rx(1.1*phase)
        world.Head = CFrame.new(0, legLength*0.002*pulse, legLength*0.005*phase)
            * fixedHead * rx(cfg.HeadSwayDegrees*phase)
        if cfg.HandMode == "Ground" then
            -- Mantem a articulacao do pescoco presa ao torso em cada quadro.
            world.Head = anchoredAt(
                (world.UpperTorso*data.Head.c0).Position,
                rx(-cfg.HeadDownDegrees + cfg.HeadSwayDegrees*phase),
                data.Head.c1)
        end
        for _, side in ipairs({"Left", "Right"}) do
            solveLeg(data, world, side, feet[side])
            if cfg.HandMode == "Ground" then
                solveArmGround(data, world, side, groundY, fixedTorso, character, cfg)
            elseif cfg.HandMode == "Wall" then
                solveArmWall(data, world, side, fixedTorso, wallZ, cfg)
            else
                solveArmOnLeg(data, world, side)
            end
        end
        local poses = {}
        for _, name in ipairs(ORDER) do
            local j = data[name]
            -- Equação da junta: Wchild = Wparent * C0 * Transform * inverse(C1).
            poses[name] = j.c0:Inverse() * world[PARENT[name]]:Inverse() * world[name] * j.c1
        end
        table.insert(frames, {time=t, poses=poses})
    end
    -- Cópia EXATA: evita o salto que ocorre se o último frame for aproximado.
    table.insert(frames, {time=duration, poses=table.clone(frames[1].poses)})
    return frames, duration
end
-- Procura tanto juntas R15 antigas como as AnimationConstraints dos rigs novos.
local function collectRig(character)
    local parts, data, joints = {}, {}, {}
    for _, name in ipairs(ORDER) do
        local part = character:FindFirstChild(name)
        if not part or not part:IsA("BasePart") then return nil end
        parts[name] = part
    end
    parts.HumanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not parts.HumanoidRootPart then return nil end
    for _, joint in ipairs(character:GetDescendants()) do
        local p0, p1, c0, c1, priority
        if joint:IsA("AnimationConstraint") then
            local a0, a1 = joint.Attachment0, joint.Attachment1
            if a0 and a1 then
                p0, p1, c0, c1, priority = a0.Parent, a1.Parent,
                    a0.CFrame, a1.CFrame, 2
            end
        elseif joint:IsA("Motor6D") then
            p0, p1, c0, c1, priority = joint.Part0, joint.Part1,
                joint.C0, joint.C1, 1
        end
        if p0 and p1 and parts[p1.Name] == p1 and parts[p0.Name] == p0
            and PARENT[p1.Name] == p0.Name
            and (not data[p1.Name] or priority > data[p1.Name].priority) then
            data[p1.Name] = {c0 = c0, c1 = c1, priority = priority}
            joints[p1.Name] = joint
        end
    end
    for _, name in ipairs(ORDER) do
        if not joints[name] then return nil end
    end
    return parts, data, joints
end
local state = {
    alive = true, mode = nil, speed = 1, width = 1, depth = 1,
    token = 0, animationToken = 0, clock = 0, connections = {},
}
local statusLabel, dance4Button, dance5Button
local function status(message)
    if statusLabel and statusLabel.Parent then statusLabel.Text = message end
end
local function paintToggle()
    for mode, button in pairs({Dance4 = dance4Button, Dance5 = dance5Button}) do
        if button and button.Parent then
            button.Text = (state.mode == mode and "PARAR " or "ATIVAR ")..mode:upper()
            button.BackgroundColor3 = state.mode == mode
                and Color3.fromRGB(164,74,112) or Color3.fromRGB(66,74,91)
        end
    end
end
-- Guarda os tamanhos anteriores da pessoa, inclusive FileMesh em rigs customizados.
local function rememberLegs(parts)
    local originals = {}
    for _, name in ipairs(LEG_NAMES) do
        local part = parts[name]
        local entry = {part = part, size = part.Size, meshes = {}}
        for _, child in ipairs(part:GetChildren()) do
            if child:IsA("FileMesh") and
                (not child:IsA("SpecialMesh") or child.MeshType == Enum.MeshType.FileMesh) then
                entry.meshes[#entry.meshes+1] = {mesh = child, scale = child.Scale}
            end
        end
        originals[#originals+1] = entry
    end
    return originals
end
local function applyWidth(width, depth)
    if not state.legOriginals then return end
    for _, entry in ipairs(state.legOriginals) do
        if entry.part.Parent then
            local original = entry.size
            entry.part.Size = V(original.X*width, original.Y, original.Z*depth)
        end
        for _, item in ipairs(entry.meshes) do
            if item.mesh.Parent then
                local original = item.scale
                item.mesh.Scale = V(original.X*width, original.Y, original.Z*depth)
            end
        end
    end
end
local function stopAnimation()
    state.animationToken += 1
    if state.frameConnection then
        state.frameConnection:Disconnect()
        state.frameConnection = nil
    end
    if state.joints then
        for _, name in ipairs(ORDER) do
            local joint = state.joints[name]
            if joint and joint.Parent then joint.Transform = CFrame.new() end
        end
    end
    state.joints = nil
    state.character = nil
end
local function cancelCharacter()
    state.token += 1
    stopAnimation()
    applyWidth(1, 1)
    state.legOriginals = nil
    state.widthCharacter = nil
    state.widthPreparing = nil
end
local function prepare(character, token, animationToken, mode)
    local function current()
        return state.alive and state.mode == mode and state.token == token
            and state.animationToken == animationToken
            and player.Character == character and character.Parent ~= nil
    end
    local deadline = os.clock()+12
    local parts, data, joints
    repeat
        if not current() then return end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.RigType ~= Enum.HumanoidRigType.R15 then
            status("Este personagem precisa ser R15")
            return
        end
        if humanoid then parts,data,joints = collectRig(character) end
        if joints then break end
        task.wait(0.1)
    until os.clock() >= deadline
    if not current() then return end
    if not joints then status("Juntas R15 nao encontradas"); return end
    local cfg = CONFIGS[mode]
    local ok, frames, duration = pcall(bake, data, cfg, character)
    if not current() then return end
    if not ok then
        warn("Dances: "..tostring(frames))
        status("Este R15 nao aceitou a animacao")
        return
    end
    state.character, state.joints, state.clock = character, joints, 0
    status(mode.." local; Width e Depth independentes")
    state.frameConnection = RunService.PreSimulation:Connect(function(dt)
        if not current() then stopAnimation(); return end
        state.clock = (state.clock+dt*state.speed)%duration
        local t = state.clock
        local index = math.clamp(math.floor(t/(duration/(#frames-1)))+1,1,#frames-1)
        local first,second = frames[index],frames[index+1]
        local alpha = math.clamp((t-first.time)/(second.time-first.time),0,1)
        for _, name in ipairs(ORDER) do
            local joint = joints[name]
            if joint and joint.Parent then
                joint.Transform = first.poses[name]:Lerp(second.poses[name],alpha)
            end
        end
    end)
end
-- O Width acompanha o personagem mesmo com a Dance4 desligada.
local function prepareWidth(character, token)
    local function current()
        return state.alive and state.token == token
            and player.Character == character and character.Parent ~= nil
    end
    local deadline = os.clock() + 12
    local legParts
    repeat
        if not current() then return end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.RigType ~= Enum.HumanoidRigType.R15 then
            state.widthPreparing = nil
            status("Este personagem precisa ser R15")
            return
        end
        if humanoid then
            local found = {}
            for _, name in ipairs(LEG_NAMES) do
                local part = character:FindFirstChild(name)
                if not part or not part:IsA("BasePart") then
                    found = nil
                    break
                end
                found[name] = part
            end
            legParts = found
        end
        if legParts then break end
        task.wait(0.1)
    until os.clock() >= deadline
    if not current() then return end
    state.widthPreparing = nil
    if not legParts then status("Pernas R15 nao encontradas"); return end
    state.legOriginals = rememberLegs(legParts)
    state.widthCharacter = character
    applyWidth(state.width, state.depth)
    if state.mode then
        status("Preparando "..state.mode.."...")
        task.spawn(prepare, character, token, state.animationToken, state.mode)
    else
        status("Width e Depth locais; dancas desligadas")
    end
end
local function watchCharacter(character)
    if not character or state.widthPreparing == character
        or state.widthCharacter == character then return end
    state.widthPreparing = character
    task.spawn(prepareWidth, character, state.token)
end
local function setMode(mode)
    if not state.alive then return end
    if state.mode == mode then mode = nil end
    state.mode = mode
    stopAnimation()
    paintToggle()
    if mode then
        status("Preparando "..mode.." no R15...")
        local character = player.Character
        if character and state.widthCharacter == character then
            task.spawn(prepare,character,state.token,state.animationToken,mode)
        else
            watchCharacter(character)
        end
    else
        status("Dancas desligadas; Width e Depth mantidos")
    end
end
local function make(className, parent, properties)
    local object = Instance.new(className)
    for key, value in pairs(properties) do object[key] = value end
    object.Parent = parent
    return object
end
local gui = make("ScreenGui", playerGui, {
    Name=GUI_NAME, ResetOnSpawn=false, DisplayOrder=15,
})
local shutdown = make("BindableFunction",gui,{Name="Shutdown"})
local panel = make("Frame",gui,{
    Name="Panel", Size=UDim2.fromOffset(246,275),
    Position=UDim2.new(0,22,0.5,-137), BorderSizePixel=0,
    BackgroundColor3=Color3.fromRGB(27,29,37),
})
make("UICorner",panel,{CornerRadius=UDim.new(0,7)})
make("UIStroke",panel,{Color=Color3.fromRGB(66,70,83),Thickness=1})
local title = make("TextButton",panel,{
    Text="Dance4 / 5  •  Local", AutoButtonColor=false,
    Position=UDim2.fromOffset(10,7),Size=UDim2.fromOffset(226,25),
    TextColor3=Color3.fromRGB(239,239,244),
    TextXAlignment=Enum.TextXAlignment.Left,
    Font=Enum.Font.GothamBold,TextSize=14,BackgroundTransparency=1,
})
local function makeDanceButton(y)
    local button=make("TextButton",panel,{
        Position=UDim2.fromOffset(10,y),Size=UDim2.fromOffset(226,29),
        BorderSizePixel=0,TextColor3=Color3.fromRGB(255,255,255),
        Font=Enum.Font.GothamBold,TextSize=12,
        BackgroundColor3=Color3.fromRGB(66,74,91),
    })
    make("UICorner",button,{CornerRadius=UDim.new(0,5)})
    return button
end
dance4Button=makeDanceButton(37)
dance5Button=makeDanceButton(70)
statusLabel=make("TextLabel",panel,{
    Position=UDim2.fromOffset(10,252),Size=UDim2.fromOffset(226,18),
    BackgroundTransparency=1,TextColor3=Color3.fromRGB(154,160,174),
    TextXAlignment=Enum.TextXAlignment.Left,Font=Enum.Font.Gotham,
    TextSize=10,Text="Width e Depth locais; dancas desligadas",
})
paintToggle()
local activeDrag, dragInput, dragStart, positionStart
local function beginDrag(mode, input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
    activeDrag, dragInput = mode, input
    dragStart = V(input.Position.X, input.Position.Y, 0)
    positionStart = panel.Position
end
title.InputBegan:Connect(function(input) beginDrag("panel", input) end)
local function slider(y, name, minimum, maximum, formatValue, onChange)
    local label = make("TextLabel", panel, {
        Position = UDim2.fromOffset(10, y), Size = UDim2.fromOffset(226, 17),
        BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(226, 227, 234),
        Font = Enum.Font.Gotham, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    local track = make("TextButton", panel, {
        Position = UDim2.fromOffset(10, y+17), Size = UDim2.fromOffset(226, 17),
        Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
    })
    local rail = make("Frame", track, {
        Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 5),
        BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(66, 70, 85),
    })
    make("UICorner", rail, {CornerRadius = UDim.new(1, 0)})
    local fill = make("Frame", rail, {
        Size = UDim2.fromScale(0, 1), BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromRGB(224, 113, 153),
    })
    make("UICorner", fill, {CornerRadius = UDim.new(1, 0)})
    local knob = make("Frame", track, {
        Size = UDim2.fromOffset(11, 11), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0, 8), BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromRGB(251, 221, 231),
    })
    make("UICorner", knob, {CornerRadius = UDim.new(1, 0)})
    local function set(value)
        value = math.clamp(value, minimum, maximum)
        local fraction = (value-minimum)/(maximum-minimum)
        label.Text = name.."   "..formatValue(value)
        fill.Size = UDim2.fromScale(fraction, 1)
        knob.Position = UDim2.new(fraction, 0, 0, 8)
        onChange(value)
    end
    local function setFromX(x)
        if track.AbsoluteSize.X > 0 then
            set(minimum + (maximum-minimum) * math.clamp(
                (x-track.AbsolutePosition.X)/track.AbsoluteSize.X, 0, 1))
        end
    end
    track.InputBegan:Connect(function(input)
        beginDrag(setFromX, input)
        if activeDrag == setFromX then setFromX(input.Position.X) end
    end)
    return set
end
local formatPercent=function(value) return string.format("%d%%",math.floor(value*100+0.5)) end
local setSpeed=slider(105,"Speed",0.25,3,
    function(value) return string.format("%.2fx",value) end,
    function(value) state.speed=value end)
local setWidth=slider(150,"Width (lados)",0.5,2,formatPercent,
    function(value) state.width=value; applyWidth(state.width,state.depth) end)
local setDepth=slider(195,"Depth (frente/tras)",0.5,2,formatPercent,
    function(value) state.depth=value; applyWidth(state.width,state.depth) end)
setSpeed(1)
setWidth(1)
setDepth(1)
state.connections[#state.connections+1] = UserInputService.InputChanged:Connect(function(input)
    if not activeDrag then return end
    if dragInput.UserInputType == Enum.UserInputType.Touch then
        if input ~= dragInput then return end
    elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then
        return
    end
    if activeDrag == "panel" then
        local difference = V(input.Position.X, input.Position.Y, 0) - dragStart
        panel.Position = UDim2.new(positionStart.X.Scale, positionStart.X.Offset+difference.X,
            positionStart.Y.Scale, positionStart.Y.Offset+difference.Y)
    else
        activeDrag(input.Position.X)
    end
end)
state.connections[#state.connections+1] = UserInputService.InputEnded:Connect(function(input)
    if dragInput and (input == dragInput or
        (dragInput.UserInputType == Enum.UserInputType.MouseButton1 and
            input.UserInputType == Enum.UserInputType.MouseButton1)) then
        activeDrag, dragInput = nil, nil
    end
end)
state.connections[#state.connections+1] = dance4Button.MouseButton1Click:Connect(function()
    setMode("Dance4")
end)
state.connections[#state.connections+1] = dance5Button.MouseButton1Click:Connect(function()
    setMode("Dance5")
end)
state.connections[#state.connections+1] = player.CharacterRemoving:Connect(function(character)
    if state.widthCharacter == character or state.widthPreparing == character
        or player.Character == character then
        cancelCharacter()
        status("Aguardando respawn R15...")
    end
end)
state.connections[#state.connections+1] = player.CharacterAdded:Connect(function(character)
    cancelCharacter()
    status("Preparando novo personagem...")
    watchCharacter(character)
end)
watchCharacter(player.Character)
local function destroy()
    if not state.alive then return end
    state.alive = false
    cancelCharacter()
    for _, connection in ipairs(state.connections) do connection:Disconnect() end
    gui:Destroy()
end
shutdown.OnInvoke = destroy
shutdown:SetAttribute("Ready", true)
-- As dancas iniciam desligadas; Width e Depth funcionam sem emote.
