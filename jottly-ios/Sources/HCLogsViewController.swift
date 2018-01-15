import UIKit

public class HCLogsViewController<LogType: HCLog>: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchResultsUpdating {

    let searchController = UISearchController(searchResultsController: nil)
    var filteredLogs = [LogType]()
    public var logsTableView: UITableView = UITableView()
    public var logger: GenericHCLogger<LogType>

    public init(logger: GenericHCLogger<LogType>) {
        // TODO: This surely cannot work
//        self.init(logger: logger)
        self.logger = logger
        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        logsTableView = UITableView(frame: UIScreen.main.bounds, style: .plain)
        logsTableView.delegate = self
        logsTableView.dataSource = self
        logsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "HCLogCell")

        searchController.searchResultsUpdater = self
        searchController.dimsBackgroundDuringPresentation = false
        definesPresentationContext = true

        logsTableView.tableHeaderView = searchController.searchBar

        self.navigationItem.setRightBarButton(
            UIBarButtonItem(
                barButtonSystemItem: .done,
                target: self,
                action: #selector(dismissViewController(_:))
            ),
            animated: true
        )

        self.view.addSubview(self.logsTableView)
    }

    @objc public func dismissViewController(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true)
    }

    // MARK: UITableViewDelegate, UITableViewDataSource

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return logger.logs.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "HCLogCell")
        let log = logger.logs.reversed()[indexPath.row]

        cell.textLabel?.text = "\(log.date.debugDescription) - \(log.text)"
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.sizeToFit()
        cell.textLabel?.lineBreakMode = .byWordWrapping

        return cell
    }

    // MARK: UISearchResultsUpdating

    public func updateSearchResults(for searchController: UISearchController) {
        // TODO
    }

    // MARK: Private instance methods

    func searchBarIsEmpty() -> Bool {
        // Returns true if the text is empty or nil
        return searchController.searchBar.text?.isEmpty ?? true
    }

    func filterContentForSearchText(_ searchText: String, scope: String = "All") {
        filteredLogs = logger.logs.filter { log in
            return log.logLevel > .verbose
        }

        logsTableView.reloadData()
    }
}


