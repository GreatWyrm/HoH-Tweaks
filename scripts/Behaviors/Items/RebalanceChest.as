class RebalanceChest : Chest
{
  RebalanceChest(UnitPtr unit, SValue& params)
  {
    super(unit, params);
  }

  void Use(PlayerBase@ player) override
  {
      	if (m_unit.IsDestroyed() || !m_unit.IsValid())
			return;
	
		if (m_lock >= 0)
		{
			if (player.m_record.keys[m_lock] <= 0 && cast<PlayerHusk>(player) is null)
			{
				AddFloatingText(FloatingTextType::Pickup, Resources::GetString(".hud.nokey"), player.m_unit.GetPosition());
				print("No key!");
				return;
			}
            // Code for the Paperclip item
            auto record = GetLocalPlayerRecord();
            if(record !is null && record.items.find("paperclip") > -1) {
                float paperclip_chance = .2f;
                if(!roll_chance(player, paperclip_chance)) {
                   player.m_record.keys[m_lock]--;
                }
            } else {
                player.m_record.keys[m_lock]--;
            }
			Stats::Add("chest-used-" + m_lock, 1, player.m_record);
		}
		else
			Stats::Add("chest-used-wood", 1, player.m_record);

		if (Network::IsServer())
		{
			m_unit.Destroy();

			if (m_lootDef !is null)
				m_lootDef.Spawn(xy(m_unit.GetPosition()));
		}

		Stats::Add("chests-opened", 1, player.m_record);
		PlaySound3D(m_openSnd, m_unit.GetPosition());
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