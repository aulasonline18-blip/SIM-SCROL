function createReviewController(t02Controller) { return {handle: (req, res) => t02Controller.handle(req, res, 'review')}; }
module.exports = {createReviewController};
