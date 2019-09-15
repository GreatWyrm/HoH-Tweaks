namespace Modifiers
{
	class SealOfRegenHealth : Modifier
	{
		vec2 m_regen;
		bool affectHealth;
		bool affectMana;
	
		SealOfRegenHealth(UnitPtr unit, SValue& params)
		{		
			m_regen = vec2(
				GetParamFloat(unit, params, "health", false, 1),
				GetParamFloat(unit, params, "mana", false, 1));
			affectHealth = GetParamBool(unit, params, "affect-health", false, false);
			affectMana = GetParamBool(unit, params, "affect-mana", false, false);
			m_regen *= GetParamFloat(unit, params, "regen", false, 1);
		}
		
		bool HasRegenAdd() override { return true; }
		
		vec2 RegenAdd(PlayerBase@ player) override {
			auto regen = vec2(0.0f, 0.0f) + m_regen * clamp(1.0f - player.m_record.hp, 0.0f, 1.0f) * 10.0f;
			if(!affectHealth) {
				regen.x = 0.0f;
			}
			if(!affectMana) {
				regen.y = 0.0f;
			}
			return regen;
		}
	}
}