"""
Holds a belief for 4 float values.

Assumes 4 actions.
"""
from cython import ccall, cclass, locals, returns

from bot_base cimport BaseBot

from interface cimport c_do_action, c_get_state


@cclass
class Bot(BaseBot):
    @staticmethod
    def shapes(steps, actions, features):
        return {
            'free': (actions,),
            'state0l': (actions, features),
            'belief0l': (actions, 4),
            'belief_free': (4,),
            'belief_state0l': (4, features),
            'belief_belief0l': (4, 4)
        }

    def __cinit__(self, *args, **kwargs):
        self.beliefs = [0] * 4

    @ccall
    @returns('Bot')
    @locals(state='bint', bot='Bot')
    def clone(self, state=True):
        bot = BaseBot.clone(self, state)
        if state:
            bot.beliefs = self.beliefs[:]
        return bot

    @ccall
    @returns('dict')
    @locals(dists='dict', emphases='tuple',
            belief_trust='float', belief_lag='float',
            multipliers='dict', params='dict')
    def new_params(self, dists, emphases):
        belief_trust = dists['unit'].rvs()
        belief_lag = dists['unit'].rvs()
        multipliers = self.param_multipliers
        multipliers['belief0l'] = belief_trust
        multipliers['belief_state0l'] = belief_lag
        multipliers['belief_belief0l'] = belief_trust * belief_lag
        params = BaseBot.new_params(self, dists, emphases)
        params['_belief_trust'] = belief_trust
        params['_belief_lag'] = belief_lag
        return params

    @ccall
    @returns('void')
    @locals(steps='int', step='int', action='int',
            features='int', feature='int',
            free='float[4]', state0l='float[:, ::1]', belief0l='float[:, ::1]',
            belief_free='float[4]', belief_state0l='float[:, ::1]',
            belief_belief0l='float[:, ::1]',
            beliefs='float[4]', beliefst='float[4]', values='float[4]',
            state0='float*', state0f='float')
    def act(self, steps):
        features = self.level['features']
        free = self.params['free']
        state0l = self.params['state0l']
        belief0l = self.params['belief0l']
        belief_free = self.params['belief_free']
        belief_state0l = self.params['belief_state0l']
        belief_belief0l = self.params['belief_belief0l']
        beliefs = self.beliefs[:]
        action = -1

        for step in range(steps):
            values = free[:]
            values[0] += (belief0l[0, 0] * beliefs[0] +
                          belief0l[0, 1] * beliefs[1] +
                          belief0l[0, 2] * beliefs[2] +
                          belief0l[0, 3] * beliefs[3])
            values[1] += (belief0l[1, 0] * beliefs[0] +
                          belief0l[1, 1] * beliefs[1] +
                          belief0l[1, 2] * beliefs[2] +
                          belief0l[1, 3] * beliefs[3])
            values[2] += (belief0l[2, 0] * beliefs[0] +
                          belief0l[2, 1] * beliefs[1] +
                          belief0l[2, 2] * beliefs[2] +
                          belief0l[2, 3] * beliefs[3])
            values[3] += (belief0l[3, 0] * beliefs[0] +
                          belief0l[3, 1] * beliefs[1] +
                          belief0l[3, 2] * beliefs[2] +
                          belief0l[3, 3] * beliefs[3])
            state0 = c_get_state()
            for feature in range(features):
                state0f = state0[feature]
                values[0] += state0l[0, feature] * state0f
                values[1] += state0l[1, feature] * state0f
                values[2] += state0l[2, feature] * state0f
                values[3] += state0l[3, feature] * state0f
            action = (((0 if values[0] > values[3] else 3)
                                if values[0] > values[2] else
                                        (2 if values[2] > values[3] else 3))
                                if values[0] > values[1] else
                        ((1 if values[1] > values[3] else 3)
                                if values[1] > values[2] else
                                        (2 if values[2] > values[3] else 3)))
            c_do_action(action)
            beliefst = belief_free[:]
            beliefst[0] += (belief_belief0l[0, 0] * beliefs[0] +
                            belief_belief0l[0, 1] * beliefs[1] +
                            belief_belief0l[0, 2] * beliefs[2] +
                            belief_belief0l[0, 3] * beliefs[3])
            beliefst[1] += (belief_belief0l[1, 0] * beliefs[0] +
                            belief_belief0l[1, 1] * beliefs[1] +
                            belief_belief0l[1, 2] * beliefs[2] +
                            belief_belief0l[1, 3] * beliefs[3])
            beliefst[2] += (belief_belief0l[2, 0] * beliefs[0] +
                            belief_belief0l[2, 1] * beliefs[1] +
                            belief_belief0l[2, 2] * beliefs[2] +
                            belief_belief0l[2, 3] * beliefs[3])
            beliefst[3] += (belief_belief0l[3, 0] * beliefs[0] +
                            belief_belief0l[3, 1] * beliefs[1] +
                            belief_belief0l[3, 2] * beliefs[2] +
                            belief_belief0l[3, 3] * beliefs[3])
            for feature in range(features):
                state0f = state0[feature]
                beliefst[0] += belief_state0l[0, feature] * state0f
                beliefst[1] += belief_state0l[1, feature] * state0f
                beliefst[2] += belief_state0l[2, feature] * state0f
                beliefst[3] += belief_state0l[3, feature] * state0f
            beliefs, beliefst = beliefst, beliefs

        self.beliefs = beliefs[:]
        self.last_action = action
