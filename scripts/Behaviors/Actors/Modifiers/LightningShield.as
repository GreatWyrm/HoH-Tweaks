namespace Modifiers
{
	class LightningShield : Modifier, IBuffWidgetInfo
	{
		float m_dmgTakenMul;

		int m_cooldown;
		int m_cooldownC;

		uint m_fxHash;
		uint m_fxChargeHash;

		UnitScene@ m_fx;
		UnitScene@ m_fxCharge;

		ScriptSprite@ m_cooldownIcon;

		LightningShield() { }
		LightningShield(UnitPtr unit, SValue& params)
		{
			m_dmgTakenMul = GetParamFloat(unit, params, "dmg-taken-mul", false, 1);

			m_cooldown = GetParamInt(unit, params, "cooldown");

			m_fxHash = HashString(GetParamString(unit, params, "fx", false));
			@m_fx = Resources::GetEffect(m_fxHash);

			m_fxChargeHash = HashString(GetParamString(unit, params, "fx-charge", false));
			@m_fxCharge = Resources::GetEffect(m_fxChargeHash);

			@m_cooldownIcon = ScriptSprite(GetParamArray(unit, params, "hud-cooldown"));
		}

		Modifier@ Instance() override
		{
			auto ret = LightningShield();
			ret = this;
			ret.m_cloned++;
			return ret;
		}

		bool HasDamageTakenMul() override { return true; }
		float DamageTakenMul(PlayerBase@ player, DamageInfo &di) override
		{
			if (m_cooldownC > 0)
				return 1;

			m_cooldownC = m_cooldown;

			auto hud = GetHUD();
			if (hud !is null)
				hud.ShowBuffIcon(player, this);

			PlayEffect(m_fx, player.m_unit);
			(Network::Message("AttachEffect") << m_fxHash << player.m_unit).SendToAll();

			return m_dmgTakenMul;
		}

		bool HasUpdate() override { return true; }
		void Update(PlayerBase@ player, int dt) override
		{
			if (m_cooldownC <= 0)
				return;

			m_cooldownC -= dt;
			if (m_cooldownC < 0)
			{
				PlayEffect(m_fxCharge, player.m_unit);
				(Network::Message("AttachEffect") << m_fxHash << player.m_unit).SendToAll();
			}
		}

		ScriptSprite@ GetBuffIcon() { return m_cooldownIcon; }
		int GetBuffIconDuration() { return m_cooldownC; }
		int GetBuffIconMaxDuration() { return m_cooldown; }
		int GetBuffIconCount() { return -1; }
	}
}
