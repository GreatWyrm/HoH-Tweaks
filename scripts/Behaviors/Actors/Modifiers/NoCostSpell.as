namespace Modifiers
{
	class NoCostSpell : Modifier
	{
        float discountChance;
		float m_manaMul;
        float m_standardCost;
	
		NoCostSpell(UnitPtr unit, SValue& params)
		{
			discountChance = GetParamFloat(unit, params, "chance", false, 0);
            m_manaMul = 0.0f;
            m_standardCost = 1.0f;
		}
		
		float SpellCostMul(PlayerBase@ player) override {
            if(roll_chance(player, discountChance)) {
                return m_manaMul;
            }
            return m_standardCost;
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
}