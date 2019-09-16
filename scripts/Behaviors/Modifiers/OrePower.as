namespace Modifiers
{
	class OrePower : Modifier
	{
		vec2 m_regen;
		bool affectHealth;
		bool affectMana;
        int oreCap;
	
		OrePower(UnitPtr unit, SValue& params)
		{		
			m_regen = vec2(
				GetParamFloat(unit, params, "health", false, 1),
				GetParamFloat(unit, params, "mana", false, 1));
			affectHealth = GetParamBool(unit, params, "affect-health", false, false);
			affectMana = GetParamBool(unit, params, "affect-mana", false, false);
			m_regen *= GetParamFloat(unit, params, "regen", false, 1);
            oreCap = GetParamInt(unit, params, "cap", false, 300);
		}
		
		bool HasRegenAdd() override { return true; }
		
		vec2 RegenAdd(PlayerBase@ player) override {
            int effectiveOre = 0;
            if(player.m_record.runOre >= oreCap) {
                effectiveOre = oreCap;
            } else {
                if(player.m_record.runOre < 0) {
                    effectiveOre = 0;
                } else {
                    effectiveOre = player.m_record.runOre;
                }
            }
			auto regen = vec2(0.0f, 0.0f) + m_regen * effectiveOre;
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