function createDoubtController(t02Controller) { return {handle: (req, res) => t02Controller.handle(req, res, 'doubt')}; }
module.exports = {createDoubtController};
