namespace Skills
{
	class DropUnitWarlock : DropUnit
	{
		float m_rangeMul = 1.75f;

		DropUnitWarlock(UnitPtr unit, SValue& params)
		{
			super(unit, params);
		}

		UnitPtr SpawnUnit(vec3 pos, vec2 target) override
		{
			UnitPtr ret = DropUnit::SpawnUnit(pos, target);

			auto a = cast<CompositeActorBehavior>(ret.GetScriptBehavior());
			if (a !is null)
			{
				for (uint i = 0; i < a.m_skills.length(); i++)
				{
					auto skill = a.m_skills[i];

					auto skillMeleeStrike = cast<EnemyMeleeStrike>(skill);
					if (skillMeleeStrike !is null)
					{
						skillMeleeStrike.m_restrictions.m_rangeSq = int(skillMeleeStrike.m_restrictions.m_rangeSq * m_rangeMul);
						continue;
					}

					auto skillComposite = cast<CompositeActorSkill>(skill);
					if (skillComposite !is null)
					{
						skillComposite.m_restrictions.m_rangeSq = int(skillComposite.m_restrictions.m_rangeSq * m_rangeMul);
						continue;
					}
				}
				return ret;
			}

			auto gargoyleSpawner = cast<GargoyleSpawner>(ret.GetScriptBehavior());
			if (gargoyleSpawner !is null)
			{
				gargoyleSpawner.m_rangeMul = m_rangeMul;
				@gargoyleSpawner.m_dropSkill = this;
				return ret;
			}

			auto boltShooter = cast<BoltShooter>(ret.GetScriptBehavior());
			if (boltShooter !is null)
				boltShooter.m_range = int(boltShooter.m_range * m_rangeMul);

			return ret;
		}
	}
}
