namespace Modifiers
{
	class GoldDamage : Modifier
	{
		float rate;
        int goldCap;
	
		GoldDamage(UnitPtr unit, SValue& params)
		{		
			rate = GetParamFloat(unit, params, "damage-rate", false, 1000);
            goldCap = GetParamInt(unit, params, "cap", false, 100000);
		}
		
		vec2 DamageMul(PlayerBase@ player, Actor@ enemy) override {
            int effectiveGold = 0;
            auto record = GetLocalPlayerRecord();
            if(record is null) {
                return vec2(1.0f, 1.0f);
            }
            int effectiveGold = clamp(record.runGold, 0, goldCap);
			return vec2(1.0f, 1.0f) * effectiveGold/rate;
		}
	}
}