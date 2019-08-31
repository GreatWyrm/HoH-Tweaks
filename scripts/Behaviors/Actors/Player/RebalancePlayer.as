%if NON_FINAL
bool g_cvar_god = false;
%endif

class RebalancePlayer : Player
{
	Player(UnitPtr unit, SValue& params)
	{
		super(unit, params);
	}
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

	void NetDamage(DamageInfo dmg, vec2 pos, vec2 dir) override
	{
		this.Damage(dmg, pos, dir);
	}

	void BroadcastNetDamage(DamageInfo di)
	{
		int damager = 0;
		if (di.Attacker !is null && di.Attacker.m_unit.IsDestroyed())
			damager = di.Attacker.m_unit.GetId();

		m_lastSentHP = m_record.hp;
		(Network::Message("PlayerDamaged") << di.DamageType << damager << di.Damage << m_record.hp << di.Weapon).SendToAll();
	}

	void OnDeath(DamageInfo di, vec2 dir) override
	{
		PlayerBase::OnDeath(di, dir);

		DisableModifiers();

		auto gm = cast<Campaign>(g_gameMode);

		Stats::Add("death-count", 1, m_record);

		if (cast<Town>(gm) is null)
			Stats::Add("floor-deaths-" + (gm.m_levelCount + 1), 1, m_record);

		int killerPeer = -1;
		
		auto plyKiller = cast<PlayerBase>(di.Attacker);
		if (plyKiller !is null)
			killerPeer = plyKiller.m_record.peer;
		
		m_record.deaths++;
		m_record.deathsTotal++;
		(Network::Message("PlayerDied") << killerPeer << int(di.DamageType) << int(di.Damage) << di.Melee << di.Weapon).SendToAll();

		PlayerRecord@ killerRecord;
		if (plyKiller !is null)
			@killerRecord = plyKiller.m_record;
		else if (di.Attacker !is null)
			cast<Campaign>(g_gameMode).m_townLocal.EnemyKilledPlayer(di.Attacker);	
			
		gm.PlayerDied(m_record, killerRecord, di);

		auto hud = GetHUD();
		if (hud !is null)
			hud.OnDeath();
	}