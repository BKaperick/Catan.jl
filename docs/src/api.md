# Configuration of a new player

`Catan.jl` allows for full customizability of scripted players using Julia's Type framework.  This is done by defining a new struct and implementing any methods for which you wish to add custom behavior, as detailed below.

For more advanced usage, see [CatanLearning.jl](https://github.com/BKaperick/CatanLearning.jl/tree/master/src/players).

## Setting up the type
Define a new player called `NewRobotPlayer` requires the definition of a `mutable struct` inheriting from `abstract type RobotPlayer`,

```julia
mutable struct NewRobotPlayer <: RobotPlayer
    player::Player

    # Here, Insert any other fields to store intermediary data or parameters during game
end
```

To let it interact with the `Catan.jl` framework, it must have a constructor accepting `(team::Symbol, configs::Dict)`, and it must be registered.  Continuing with our above example,
```julia
NewRobotPlayer(team::Symbol, configs::Dict) = NewRobotPlayer(Player(team, configs))
Catan.add_player_to_register("New Robot Player Experiment", 
(t,c) -> NewRobotPlayer(t,c),
p -> NewRobotPlayer(p))
```

and now it can be used in gameplay by configuring the player in the configuration TOML file,
```toml filename="Configuration.toml"
...
[PlayerSettings]
[PlayerSettings.blue]
TYPE = "New Robot Player Experiment" 
[PlayerSettings.cyan]
TYPE = "DefaultRobotPlayer"
[PlayerSettings.green]
TYPE = "DefaultRobotPlayer"
[PlayerSettings.yellow]
TYPE = "DefaultRobotPlayer"
...
```

## Methods for defining custom player behavior

An exhaustive list of methods that can be implemented to override the default behavior (uniform random) of the `DefaultRobotPlayer`, ordered roughly in order of descending importance for gameplay.

### High-level decisions
```@docs
choose_next_action
```

### Construction
```@docs
choose_building_location
choose_road_location
```

### Robbers and knights
```@docs
choose_place_robber
choose_robber_victim
choose_one_resource_to_discard
```

### Development cards
```@docs
choose_resource_to_draw
choose_monopoly_resource
```

### Trading
```@docs
choose_accept_trade
choose_who_to_trade_with
```

### Optimization and data generation
```@docs
initialize_player
do_post_game_action
```

