# "not_change" is needed to support chaining "change" matchers
# see https://stackoverflow.com/a/34969429/58876
RSpec::Matchers.define_negated_matcher :not_change, :change

# Needed to discriminate "enqueued A and NOT B" inside a single `expect { }`
# block with `.and` -- calling check_thresholds! twice to assert the second
# mail didn't fire would let a 24h-cooldown key from the first mail mask a
# bug that fires both mails on the same call.
RSpec::Matchers.define_negated_matcher :not_have_enqueued_mail, :have_enqueued_mail
