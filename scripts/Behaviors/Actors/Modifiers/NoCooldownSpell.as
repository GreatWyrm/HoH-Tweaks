namespace Modifiers
{
	class NoCooldownSpell : Modifier
	{
        float noCooldownChance;
		float m_skillSpeedMul;
	
		NoCooldownSpell(UnitPtr unit, SValue& params)
		{
			noCooldownChance = GetParamFloat(unit, params, "chance", false, 0);
            m_skillSpeedMul = 10.0f;
		}
		
		float SkillTimeMul(PlayerBase@ player) override {
            if(roll_chance(player, noCooldownChance)) {
                return m_skillSpeedMul;
            }
            return 1.0f;
        }
	}
    bool roll_chance(PlayerBase@ player, float chance, bool flipLuck = false)
    {
	    float c = clamp(chance, 0.0f, 1.0f);
	    if (player !is null && player.m_currLuck != 0)
	    {
		    float l = player.m_currLuck * (flipLuck ? -1 : 1);
		    c = 1 - pow(1 - c, pow(2, l / 10.0f));
	    }
	
	    return randf() <= c;
    }
}