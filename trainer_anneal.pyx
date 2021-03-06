"""
A "probabilistic", simplified simulated annealing.

At each step a number of parameters are redrawn and the bot is evaluated with
the new parameters. Then a random threshold is drawn and scaled by a power of
the fraction of the level left. The resulting value is compared with the
returns change, if the growth or decline of the total score is greater than
the scaled threshold the new params are kept, otherwise the search continues
with the previous set.

The config should consist of three values: the number of steps (integer),
an easing factor for the effects of the acceptance distribution (float),
and a variation scale (float).

The thresholds drawn from the acceptance distribution are multiplied by the
fraction of the level left raised to the power of the easing factor, thus a
factor of 0 lets declines be accepted (with some probability) from the start
till the end of the training session, while a high factor only allows declines
to be accepted at the beginning of it.

If the variation scale is less than 1, new param entries are interpolated
between newly drawn values and their old values (rather than being redrawn
anew).

Two probability distributions are used: --dist_variations controls the number
of parameters changed at once at each step, and --dist_acceptance decides
whether to continue with a mutated bot or keep the previous one.
"""
from cython import ccall, cclass, returns

from trainer_local cimport Trainer as TrainerLocal


@cclass
class Trainer(TrainerLocal):
    arguments = (
        ('steps', int),
        ('acceptance_ease', float),
        ('change', float)
    )

    @ccall
    @returns('tuple')
    def train(self):
        variations_dist = self.dists['variations']
        acceptance_dist = self.dists['acceptance']
        best_score = float('-inf')
        best_bot = None
        best_history = []

        for bot, history in self.seeds:
            best_seed_score = bot.evaluate(self.runs)
            best_seed_bot = bot

            for step in range(self.steps):
                bot = best_seed_bot.clone(state=False)
                change = self.change
                variations = max(1, round(variations_dist.rvs()))
                bot.vary_params(self.dists, self.emphases, change, variations)
                score = bot.evaluate(self.runs)
                improvement = score - best_seed_score
                mult = pow(1 - float(step) / self.steps, self.acceptance_ease)
                if acceptance_dist.rvs() * mult < improvement:
                    best_seed_score = score
                    best_seed_bot = bot

            if best_seed_score > best_score:
                best_score = best_seed_score
                best_bot = best_seed_bot
                best_history = history

        return best_bot.params, best_history
