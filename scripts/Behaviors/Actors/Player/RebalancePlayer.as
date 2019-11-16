%if NON_FINAL
bool g_cvar_god = false;
%endif

class RebalancePlayer : Player
{
	bool debuffImmune;
	int debuffImmuneTime;
	RebalancePlayer(UnitPtr unit, SValue& params)
	{
		super(unit, params);
		debuffImmune = false;
		debuffImmuneTime = 0;
	}

	
	int Damage(DamageInfo dmg, vec2 pos, vec2 dir) override
	{
		if (
%if NON_FINAL
			g_cvar_god ||
%endif
			m_record.IsDead())
		{
			return 0;
		}

		if (g_gameMode.m_gameTime - m_spawnTime < Tweak::SpawnInvulnTime)
			return 0;

		bool isTrapDamage = (dmg.Attacker is null);

		bool selfDmg = false;
		if (dmg.Attacker is this)
		{
			@dmg.Attacker = null;
			selfDmg = true;
		}

		int maxHp = m_record.MaxHealth();		
		vec2 armor(m_record.Armor(), m_record.Resistance());
		ivec2 block;
		float dmgTakenMul = 1.0f;

		if (g_allModifiers.NonLethalDamage(this, dmg))
			dmg.CanKill = false;

		if (dmg.DamageType != 0)
		{
			if (!dmg.TrueStrike)
			{
				if (g_allModifiers.Evasion(this, dmg.Attacker))
				{
					Stats::Add("evade-amount", 1, m_record);
					g_allModifiers.TriggerEffects(this, dmg.Attacker, Modifiers::EffectTrigger::Evade);
					m_dmgColor = vec4(0, 0, 0, 2.0);
					PlaySound3D(m_sndEvade, m_unit);
					debuffImmune = true;
					debuffImmuneTime = 5;
					return 0;
				}
				
				block += g_allModifiers.DamageBlock(this, dmg.Attacker);

				vec2 blockMul = g_allModifiers.DamageBlockMul(this, dmg.Attacker);
				if (blockMul.x < 1.0f)
					block.x += int((1.0f - blockMul.x) * dmg.PhysicalDamage);
				if (blockMul.y < 1.0f)
					block.y += int((1.0f - blockMul.y) * dmg.MagicalDamage);
				
				if (block.x + block.y > 0)
				{
					Stats::Add("damage-blocked", block.x + block.y, m_record);
					
					if (block.x > 0)
						PlayEffect(m_fxBlockPhysical, pos);
					else
						PlayEffect(m_fxBlockMagical, pos);
				}
				
				if (dmg.PhysicalDamage > 0)
					dmg.PhysicalDamage = max(0, dmg.PhysicalDamage - block.x);
				
				if (dmg.MagicalDamage > 0)
					dmg.MagicalDamage = max(0, dmg.MagicalDamage - block.y);
			}
			
			armor += g_allModifiers.ArmorAdd(this, dmg.Attacker);
			maxHp += g_allModifiers.StatsAdd(this).x;
			maxHp = int(maxHp * g_allModifiers.MaxHealthMul(this));
			maxHp = max(1, maxHp);

			float trapMultiplier = 1.0f;
			if (isTrapDamage)
			{
				if (Fountain::HasEffect("reduced_trap_damage"))
					trapMultiplier *= 0.5f;
				if (Fountain::HasEffect("more_trap_damage"))
					trapMultiplier *= 2.0f;
				if (m_record.items.find("steel-toe-boots") != -1) {
					trapMultiplier *= 0.85f;
				}
			}

			float hc = 1.0f; //lerp(1.0f, 0.8f, m_record.GetHandicap());
			dmgTakenMul *= hc * trapMultiplier * g_allModifiers.DamageTakenMul(this, dmg) * m_buffs.DamageTakenMul();
		}

		auto enemy = cast<CompositeActorBehavior>(dmg.Attacker);
		if (enemy !is null)
		{
			auto entry = enemy.GetBestiaryAttunement();
			if (entry !is null)
				dmgTakenMul *= pow(0.95, entry.m_attuned);
		}
		
		if (m_cachedCurses > 0 && !roll_chance(this, pow(0.99f, m_cachedCurses)))
		{
			PlayEffect(m_fxCurseCrit, m_unit.GetPosition());
			dmgTakenMul *= 2.0f + 0.01f * m_cachedCurses;
		}
		
		vec2 armorMul = g_allModifiers.ArmorMul(this, null) * m_buffs.ArmorMul();
		int dmgAmnt = ApplyArmor(dmg, armorMul * armor * dmg.ArmorMul - Tweak::NewGamePlusNegArmor(g_ngp), dmgTakenMul);
		if (dmgAmnt > 0)
		{
			if (!dmg.CanKill || g_isTown)
				dmgAmnt = min(m_record.CurrentHealth() - 1, dmgAmnt);
			
			bool evadable = dmg.Melee && dmg.Attacker !is null && !dmg.Attacker.IsDead();
			
			m_returningDamage = true;
			
			if (selfDmg)
				g_allModifiers.TriggerEffects(this, dmg.Attacker, Modifiers::EffectTrigger::HurtSelf);
			else
				g_allModifiers.TriggerEffects(this, dmg.Attacker, Modifiers::EffectTrigger::HurtNonSelf);
			
			g_allModifiers.TriggerEffects(this, dmg.Attacker, Modifiers::EffectTrigger::Hurt);
			g_allModifiers.DamageTaken(this, dmg.Attacker, dmgAmnt);
			m_returningDamage = false;

			if (m_record.items.find("phoenix-feather") != -1)
			{
				int testHealth = m_record.CurrentHealth() - dmgAmnt;
				while (testHealth <= 0)
				{
					int charges = 1 + g_allModifiers.PotionCharges();
					int availableCharges = charges - m_record.potionChargesUsed;
					if (availableCharges <= 0)
						break;

					int healed = ForceDrinkPotion();
					testHealth += healed;
					dmgAmnt -= healed;
				}
			}
		
			if (evadable && dmg.Attacker.IsDead())
			{
				g_allModifiers.TriggerEffects(this, dmg.Attacker, Modifiers::EffectTrigger::Evade);
				m_dmgColor = vec4(0, 0, 0, 2.0);
				PlaySound3D(m_sndEvade, m_unit);
				return 0;
			}
			
			float new = float(m_record.hp) - float(dmgAmnt) / float(maxHp);
			m_record.hp = new;
			assert(m_record.hp, new);
			AddFloatingHurt(dmgAmnt, dmg.Crit, dmg.MagicalDamage > dmg.PhysicalDamage ? FloatingTextType::PlayerHurtMagical : FloatingTextType::PlayerHurt);
			m_dmgColor = vec4(1, 0, 0, 1);
			
			int manaFromDamage = g_allModifiers.ManaFromDamage(this, dmgAmnt);
			if (manaFromDamage > 0)
				this.GiveMana(manaFromDamage);

			Stats::Add("damage-taken", dmgAmnt, m_record);
			Stats::Max("damage-taken-max", dmgAmnt, m_record);
			

			//if (dmgAmnt > 5)
			//	MusicManager::AddTension(2.5);
			
			if (m_record.CurrentHealth() <= 0)
			{
				//dmg.Damage = dmgAmnt;
				//BroadcastNetDamage(dmg);
				OnDeath(dmg, dir);
				return dmgAmnt;
			}
			else
			{
				if (m_gore !is null)
					m_gore.OnHit(float(dmgAmnt) / float(maxHp), pos, atan(dir.y, dir.x));

				dictionary params = { { "damage", float(dmgAmnt) } };

				if (!selfDmg)
					PlaySound3D(m_voice.m_soundHurt, m_unit, params);
			}
		}
		else if (dmgAmnt < 0)
		{
			if (m_record.hp < 1.0)
				return -Heal(-dmgAmnt);
			else
				return 0;
		}
		else
		{
			AddFloatingHurt(0, dmg.Crit, dmg.MagicalDamage > dmg.PhysicalDamage ? FloatingTextType::PlayerHurtMagical : FloatingTextType::PlayerHurt);
		}

		dmg.Damage = dmgAmnt;
		BroadcastNetDamage(dmg);
		return dmgAmnt;
	}
	bool ApplyBuff(ActorBuff@ buff) override
	{ 
		if (BlockBuff(buff, m_record.armorDef, m_record.armor))
			return false;
		if(debuffImmune && buff.m_def.m_debuff) {
			debuffImmune = false;
			debuffImmuneTime = 0;
			return false;
		}
		return PlayerBase::ApplyBuff(buff);
	}
		void Update(int dt) override
	{
%PROFILE_START BaseUpdate
		PlayerBase::Update(dt);
%PROFILE_STOP
		
		if (m_potionDelay > 0)
			m_potionDelay -= dt;
		
		auto input = GetInput();
		
		auto aimDir = input.AimDir;
		auto moveDir = input.MoveDir;
		if (m_buffs.Confuse() && !m_buffs.AntiConfuse())
		{
			aimDir *= -1;
			moveDir *= -1;
		}
		
		int cc = max(0, m_record.curses + g_allModifiers.CursesAdd(this));
		if (m_cachedCurses != cc)
		{
			m_cachedCurses = cc;
			m_curseBuffIcon.RefreshIcon();
		}
		if(debuffImmuneTime > 0) {
			debuffImmuneTime--;
			if(debuffImmuneTime == 0) {
				debuffImmune = false;
			}
		}
		if (m_buffs.Drifting())
		{
			m_record.driftingOffset += 0.75f / dt;
			
			float ang = (sin(m_record.driftingOffset * 0.5f) - m_record.driftingOffset * 0.15f) * 0.4f;
			float a;
			
			a = atan(aimDir.y, aimDir.x) + ang;
			aimDir = vec2(cos(a), sin(a)) * length(aimDir);
			
			a = atan(moveDir.y, moveDir.x) + ang;
			moveDir = vec2(cos(a), sin(a)) * length(moveDir);
		}
		else
			m_record.driftingOffset = 0.0f;

		if (m_buffs.LockMovement())
			moveDir = vec2();

		if (m_buffs.LockRotation())
			aimDir = vec2(cos(m_dirAngle), sin(m_dirAngle));
			
		g_allModifiers.Update(this, dt);
		m_currLuck = g_allModifiers.LuckAdd(this);

		{ if (m_hello < 2.0f) { m_hello = randf(); } float x = m_hello * randf(); x = m_hello / randf(); if (m_hello >= 2.0f) { m_unit.SetPosition(vec3()); } }

		vec2 regen = (vec2(m_record.HealthRegen(), m_record.ManaRegen()) + g_allModifiers.RegenAdd(this)) * g_allModifiers.RegenMul(this);
		ivec2 stats = g_allModifiers.StatsAdd(this);
		
		m_effectParams.Set("hp_regen", (m_record.hp < 1.0f) ? regen.x : 0.f);
		m_effectParams.Set("mp_regen", (m_record.mana < 1.0f) ? regen.y : 0.f);

		float hpGainScale = g_allModifiers.AllHealthGainScale(this);
		float hpMax = (m_record.MaxHealth() + stats.x) * g_allModifiers.MaxHealthMul(this);
		
		m_record.hp = clamp(m_record.hp + dt / 1000.0f * (regen.x * hpGainScale) / hpMax, 0.0f, 1.0f);
		m_record.mana = clamp(m_record.mana + dt / 1000.0f * regen.y / (m_record.MaxMana() + stats.y), 0.0f, 1.0f);

		if (m_queuedHealing > 0)
		{
			float healing = min(hpMax / 1000.0f * dt, m_queuedHealing);
			if (m_record.hp * hpMax + healing > hpMax)
			{
				healing = float(hpMax - m_record.hp * hpMax);
				m_queuedHealing = 0;
			}
			else
				m_queuedHealing -= healing;
				
			m_record.hp = min(1.f, m_record.hp + healing / hpMax);
		}
		
		if (abs(m_lastSentHP - m_record.hp) > 0.001f || abs(m_lastSentMana - m_record.mana) > 0.001f)
		{
			m_lastSentHP = m_record.hp;
			m_lastSentMana = m_record.mana;
			(Network::Message("PlayerSyncStats") << m_lastSentHP << m_lastSentMana).SendToAll();
		}

		auto baseGameMode = cast<BaseGameMode>(g_gameMode);

		HUD@ hud = GetHUD();
		bool freezeControls = IsDead() or baseGameMode.ShouldFreezeControls();
			
		
		int snapAngleCount = GetVarInt("g_movedir_snap");
		if (snapAngleCount > 0 && lengthsq(moveDir) > 0)
		{
			float snapAngle = TwoPI / float(snapAngleCount);
			float curAngle = atan(moveDir.y, moveDir.x);
			float snappedAngle = round(curAngle / snapAngle) * snapAngle;
			moveDir.x = cos(snappedAngle);
			moveDir.y = sin(snappedAngle);
		}

		if (m_djinnSpawnTime > 0)
		{
			m_djinnSpawnTime -= dt;
			if (m_djinnSpawnTime <= 0)
			{
				m_djinnSpawnEffect.Destroy();
				m_djinnSpawnEffect = UnitPtr();

				auto prodGenie = Resources::GetUnitProducer("players/summons/potion_djinn.unit");
				if (prodGenie !is null)
				{
					if (Network::IsServer())
					{
						m_djinn = prodGenie.Produce(g_scene, m_djinnSpawnPos);
						auto newGenie = cast<PlayerOwnedActor>(m_djinn.GetScriptBehavior());
						newGenie.Initialize(this, 1.0f, false);

						(Network::Message("SetOwnedUnit") << m_djinn << m_unit << 1.0f).SendToAll();
					}
					else
						(Network::Message("PlayerPotionDjinn")).SendToHost();
				}
			}
		}
		
%PROFILE_START SkillInput

		int skillDt = int(m_currentAttackSpeed.y * dt);
		if (!freezeControls)
		{
			if (!m_buffs.Silence())
			{
				CheckUseSkill(skillDt, input.Attack4, m_skills[3], aimDir);
				CheckUseSkill(skillDt, input.Attack3, m_skills[2], aimDir);
				CheckUseSkill(skillDt, input.Attack2, m_skills[1], aimDir);

				if (input.Attack1.Pressed)
				{
					auto skill = cast<Skills::ActiveSkill>(m_skills[0]);
					if (skill !is null)
					{
						if (skill.m_cooldownC > 0 && g_allModifiers.CooldownClear(this, skill))
						{
							skill.m_cooldownC = 0;
							skill.m_cooldownOverride = true;
						}
						else
							skill.m_cooldownOverride = false;
					}
				}
			}

			if (input.Attack1.Down && !input.Ping.Down && !m_buffs.Disarm() && !CheckSkillBlocked(m_skills[0]))
			{
				if (m_skills[0].Activate(aimDir))
					g_allModifiers.TriggerEffects(this, null, Modifiers::EffectTrigger::Attack);
			}

			if (input.Potion.Pressed && m_potionDelay <= 0)
			{
				DrinkPotion();
				m_potionDelay = GetVarInt("g_potion_delay");
				Tutorial::RegisterAction("potion");
			}

			if (input.Use.Pressed)
			{
				auto usable = GetTopUsable();
				if (usable !is null && usable.CanUse(this))
				{
					Tutorial::RegisterAction("use");
				
					UnitPtr unit = usable.GetUseUnit();
					UnitProducer@ prod = unit.GetUnitProducer();
					if (prod !is null && prod.GetNetSyncMode() == NetSyncMode::None)
						usable.Use(this);
					else if (Network::IsServer())
					{
						(Network::Message("UseUnit") << unit << m_unit).SendToAll();
						usable.Use(this);
					}
					else
						(Network::Message("UseUnitSecure") << unit).SendToHost();
				}
			}
		}

%PROFILE_STOP

		PhysicsBody@ bdy = m_unit.GetPhysicsBody();
		vec2 dir = vec2(cos(m_dirAngle), sin(m_dirAngle));

		// If we have no physics body, we can't do much (player died)
		if (bdy is null)
			return;

%PROFILE_START Moving

		float moveSpeed = Tweak::PlayerSpeed;
		
		float slowScale = g_allModifiers.SlowScale(this);
		moveSpeed += g_allModifiers.MoveSpeedAdd(this, slowScale);
		moveSpeed *= g_allModifiers.MoveSpeedMul(this, slowScale);
		moveSpeed *= m_buffs.MoveSpeedMul(slowScale);

		for (uint i = 0; i < m_skills.length(); i++)
		{
			float speedMod = m_skills[i].GetMoveSpeedMul();
			if (speedMod >= 1.0f || !m_comboActive)
				moveSpeed *= speedMod;
			else
				moveSpeed *= lerp(speedMod, 1.0, 0.5);
		}

		array<Tileset@>@ tilesets = g_scene.FetchTilesets(xy(m_unit.GetPosition()));
		for (int i = tilesets.length() - 1; i >= 0; i--)
		{
			auto tsd = tilesets[i].GetData();
			if (tsd is null)
				continue;

			SValue@ tilesetSpeed = tsd.GetDictionaryEntry("walk-speed");
			if (tilesetSpeed !is null && tilesetSpeed.GetType() == SValueType::Float)
			{
				moveSpeed *= tilesetSpeed.GetFloat();
				break;
			}
		}
		
		moveSpeed = min(moveSpeed, Tweak::PlayerSpeedMax);
		float minSpeed = m_buffs.MinSpeed();
		auto moveDirLen = length(moveDir);
		
		if (moveDirLen < minSpeed)
			moveDir = normalize((moveDirLen > 0) ? moveDir : aimDir) * minSpeed;

		moveDir = freezeControls ? vec2() : (moveDir * moveSpeed);
		
		for (uint i = 0; i < m_skills.length(); i++)
		{
			vec2 skillMoveDir = m_skills[i].GetMoveDir();
			if (skillMoveDir.x != 0 || skillMoveDir.y != 0)
			{
				moveDir = skillMoveDir;
				break;
			}
		}
		

		int distance = int(length(moveDir));
		if (distance > 0)
			Stats::Add("units-traveled", distance, m_record);
		
		bdy.SetLinearVelocity(moveDir);
		
		float facing = atan(aimDir.y, aimDir.x);
		SetAngle(facing);
		
		bool walking = (lengthsq(bdy.GetLinearVelocity()) > 0.1);
		
		string scene = walking ? m_walkAnim.GetSceneName(facing) : m_idleAnim.GetSceneName(facing);
		SetBodyAnim(scene, false);
		if (m_playerBobbing)
			m_unit.SetPositionZ(walking ? ((m_unit.GetUnitSceneTime() / 125) % 2) : 0);
			
		UpdateFootsteps(dt, false);
		
%PROFILE_STOP
		
		
%PROFILE_START SkillUpdate

		m_skills[0].Update(int(m_currentAttackSpeed.x * dt), walking);
		for (uint i = 1; i < m_skills.length(); i++)
			m_skills[i].Update(skillDt, walking);

%PROFILE_STOP

		vec2 currDir = bdy.GetLinearVelocity();
		if (length(currDir) > 0.2)
			m_lastDirection = currDir;
		
		SendPlayerMove(dir);
	}
	int ForceDrinkPotion() override
	{
		float healAmnt = 50 * g_allModifiers.PotionHealMul(this);
		float manaAmnt = 50 * g_allModifiers.PotionManaMul(this);
		int charges = 1 + g_allModifiers.PotionCharges();

		if (charges <= m_record.potionChargesUsed)
			return 0;

		m_record.potionChargesUsed++;
		int heal = int((healAmnt + 0.5f) * g_allModifiers.AllHealthGainScale(this) / 2);
		heal += m_record.MaxHealth() / 10;

		NetHeal(heal);
		(Network::Message("PlayerHealed") << int(healAmnt) << m_record.hp).SendToAll();
		Stats::Add("amount-healed", heal, m_record);
		AddFloatingText(FloatingTextType::PlayerHealed, "" + int(healAmnt + 0.5f), m_unit.GetPosition());

		this.GiveMana(int(manaAmnt + 0.5f)/2);
		this.GiveMana(m_record.MaxMana()/10);

		PlaySound3D(Resources::GetSoundEvent("event:/player/drink_potion"), m_unit.GetPosition());
		Stats::Add("potion-charges-used", 1, m_record);
		g_allModifiers.TriggerEffects(this, null, Modifiers::EffectTrigger::DrinkPotion);

		if (m_record.desertNewGamePlus > 0)
		{
			if (m_djinn.IsValid())
			{
				if (Network::IsServer())
					m_djinn.Destroy();
				m_djinn = UnitPtr();
			}

			if (m_djinnSpawnEffect.IsValid())
			{
				m_djinnSpawnEffect.Destroy();
				m_djinnSpawnEffect = UnitPtr();
			}

			auto effect = Resources::GetEffect("players/summons/potion_djinn_spawn.effect");
			m_djinnSpawnTime = effect.Length();
			m_djinnSpawnEffect = PlayEffect(effect, m_unit.GetPosition());
			m_djinnSpawnPos = m_unit.GetPosition();

			(Network::Message("PlayerPotionDjinnBegin")).SendToAll();
		}

		return heal;
	}
}