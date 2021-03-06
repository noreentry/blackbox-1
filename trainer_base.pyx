from cython import ccall, cclass, locals, returns


@cclass
class BaseTrainer:
    """
    Abstract trainer class, defines the interface, exposes level data.

    Trainer subclasses ought to provide a configuration specification as an
    "arguments" attribute. Each entry of the sequence should be a pair of a
    property name and a function to parse the value for it.
    """
    arguments = ()

    @locals(level='dict', config='tuple', dists='dict', emphases='tuple',
            seeds='tuple', runs='int')
    def __init__(self, level, config, dists, emphases, seeds, runs):
        """
        Initializes the trainer for the given level and configuration.

        The config is trainer-specific, but the first parameter is usually the
        number of steps or the time of the optimization.

        The distributions are used for generating new parameters or as a
        further training configuration.

        Emphases multiply parameters directly relating to state components
        (with "state" in the key).

        Seeds should be a tuple of (bot, params history) pairs.

        Runs is a number of times the level should be played with each
        parameters to average out bot's randomness.
        """
        self.level = level
        self.dists = dists
        self.emphases = emphases
        self.seeds = seeds
        self.runs = runs

        arguments_desc = ", ".join("{}: {}".format(n, t.__name__)
                                   for n, t in self.arguments)
        if len(config) < len(self.arguments):
            raise ValueError("Too few arguments ({})".format(arguments_desc))
        if len(config) > len(self.arguments):
            raise ValueError("Too many arguments ({})".format(arguments_desc))
        for (arg, parser), value in zip(self.arguments, config):
            setattr(self, arg, parser(value))

    @ccall
    @returns('tuple')
    def train(self):
        """
        The main trainer function, returns the new params and their history.
        """
        raise NotImplementedError()
