namespace Modifiers
{
	class ShoppingCoupon : Modifier
	{

		ShoppingCoupon(UnitPtr unit, SValue& params)
		{
		}

		float ShopCostMul(PlayerBase@ player, Upgrades::UpgradeStep@ step) override
		{
			if(player.m_record.generalStoreItemsBought == 0) {
				return 0.0f;
			} else {
				return 1.0f;
			}
		}
	}
}
