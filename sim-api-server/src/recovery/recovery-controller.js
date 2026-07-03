function createRecoveryController(t02Controller) { return {handle: (req, res) => t02Controller.handle(req, res, 'recovery')}; }
module.exports = {createRecoveryController};
