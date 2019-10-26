namespace Modifiers
{
	class KeyPower : Modifier
	{
        array<int> keyPower(4);
        int keyCap;
	
		KeyPower(UnitPtr unit, SValue& params)
		{	
            keyPower[0] = GetParamInt(unit, params, "bronze-power", false, 1);
            keyPower[1] = GetParamInt(unit, params, "silver-power", false, 2);
            keyPower[2] = GetParamInt(unit, params, "gold-power", false, 3);
            keyPower[3] = GetParamInt(unit, params, "ace-power", false, 5);
            keyCap = GetParamInt(unit, params, "cap", false, 15);	
		}
		ivec2 DamagePower(PlayerBase@ player, Actor@ enemy) override {
            ivec2 totalPower = ivec2(0, 0);
            auto record = GetLocalPlayerRecord();
            if(record is null) {
                return totalPower;
            }
            for(uint i = 0; i < keyPower.length(); i++) {
                int effectiveKeyPower = clamp(record.keys[i], 0, keyCap);
                totalPower += (ivec2(1, 1) * effectiveKeyPower * keyPower[i]);
            }
            return totalPower;
        }
	}
}